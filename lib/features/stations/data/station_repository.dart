import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/constants/env.dart';
import 'package:ev_tool_app/core/domain/stations.dart';
import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/utils/logger.dart';

/// Open Charge Map 专用无鉴权 Dio（沿用小程序 createNoAuthRequest 约束：
/// 第三方接口不注入 Bearer token，15s 超时）。
///
/// 注意：绝不复用应用的 dioProvider（带鉴权拦截器与 401 刷新链路，
/// 会把本站用户 token 发给第三方域）。
final stationsDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://api.openchargemap.org/v3',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
});

/// 充电站服务异常（页面据此渲染错误态）。
class StationServiceException implements Exception {
  const StationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 附近充电桩仓储（数据源 Open Charge Map /v3/poi/）。
///
/// - 搜索半径 5km（海外桩密度低），maxresults 30；
/// - 结果按坐标分格 + 30 分钟 TTL 缓存于 KeyValueStore，命中后按当前
///   原点重算距离；
/// - 无 key 可用（受限流约束），配置 OCM_API_KEY 可提高配额；
/// - 错误策略与项目其他仓储一致：log + throw [StationServiceException]，
///   由页面 catch 后渲染错误态。
class StationRepository {
  StationRepository({required Dio dio, required KeyValueStore kv})
    : _dio = dio,
      _kv = kv;

  /// 结果缓存在本机的 key（按坐标分格 + TTL，同位置复用）。
  static const String nearbyStationsCacheKey = 'nearbyStationsCache';

  /// 搜索半径（km）——海外充电桩密度远低于国内，1km 常返回空。
  static const int _searchRadiusKm = 5;
  static const int _maxResults = 30;

  final Dio _dio;
  final KeyValueStore _kv;

  /// 搜索坐标附近的充电桩（按距离升序）。
  ///
  /// 同位置（坐标分格相同）30 分钟内直接复用缓存并按当前原点重算距离；
  /// 未命中 / 过期 / [force] 时请求接口并更新缓存。
  Future<List<Station>> searchNearbyStations(
    double latitude,
    double longitude, {
    bool force = false,
  }) async {
    final origin = LatLng(latitude: latitude, longitude: longitude);
    final cell = getCacheCell(origin);
    if (!force) {
      final cached = _readCache(cell);
      if (cached != null) {
        return sortStationsByDistance(rebaseStationDistances(cached, origin));
      }
    }
    final stations = await _fetchNearbyStations(origin);
    await _writeCache(cell, stations);
    return sortStationsByDistance(stations);
  }

  /// 读取可用的缓存（同 cell 且未过 TTL），脏数据一律视为未命中。
  List<Station>? _readCache(CacheCell cell) {
    final dynamic raw;
    try {
      raw = _kv.getJson(nearbyStationsCacheKey);
    } on Exception catch (e) {
      appLogger.e('Failed to read station cache', error: e);
      return null;
    }
    if (raw is! Map) {
      return null;
    }
    final dynamic list = raw['stations'];
    if (list is! List) {
      return null;
    }
    final latCell = _toDouble(raw['latCell']);
    final lngCell = _toDouble(raw['lngCell']);
    final savedAt = _toInt(raw['savedAt']);
    if (latCell == null || lngCell == null || savedAt == null) {
      return null;
    }
    final stations = <Station>[];
    for (final item in list) {
      if (item is! Map) continue;
      final station = _stationFromJson(item.cast<String, dynamic>());
      if (station != null) stations.add(station);
    }
    final cache = StationCache(
      latCell: latCell,
      lngCell: lngCell,
      stations: stations,
      savedAt: savedAt,
    );
    if (!isCacheFresh(cache, cell, DateTime.now().millisecondsSinceEpoch)) {
      return null;
    }
    return stations;
  }

  /// 写入缓存，失败仅 log 不影响主流程。
  Future<void> _writeCache(CacheCell cell, List<Station> stations) async {
    try {
      await _kv.setJson(nearbyStationsCacheKey, <String, dynamic>{
        'latCell': cell.latCell,
        'lngCell': cell.lngCell,
        'stations': [for (final station in stations) _stationToJson(station)],
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } on Exception catch (e) {
      appLogger.e('Failed to save station cache', error: e);
    }
  }

  /// 请求 /poi/ 并归一化（保持接口返回序，排序由调用方决定）。
  Future<List<Station>> _fetchNearbyStations(LatLng origin) async {
    final body = await _getList(
      '/poi/',
      queryParameters: <String, dynamic>{
        'latitude': origin.latitude,
        'longitude': origin.longitude,
        'distance': _searchRadiusKm,
        'distanceunit': 'KM',
        'maxresults': _maxResults,
        'compact': true,
        'output': 'json',
        // 可选 key：无 key 可用但受限流约束，配置后提高配额
        if (Env.ocmKey.isNotEmpty) 'key': Env.ocmKey,
      },
    );
    final stations = <Station>[];
    for (final poi in body) {
      if (poi is! Map) continue;
      final station = normalizeStation(poi.cast<String, dynamic>(), origin);
      if (station != null) stations.add(station);
    }
    return stations;
  }

  /// 无鉴权 GET（OCM 接口专用）；响应为 JSON 数组。
  /// 网络失败 / 限流（403/429）归一化为 [StationServiceException]。
  Future<List<dynamic>> _getList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      final data = response.data;
      if (data is List) {
        return data;
      }
      // Content-Type 非 JSON 时 dio 不解码（String 原样返回），手动解析
      if (data is String && data.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is List) {
            return decoded;
          }
        } on FormatException {
          // 非 JSON 字符串 → 走空 List，由调用方按空结果处理
        }
      }
      return const <dynamic>[];
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final isRateLimited = statusCode == 403 || statusCode == 429;
      if (isRateLimited) {
        appLogger.w('Charging station service rate limited', error: e);
        throw const StationServiceException(
          'Charging station service is busy, please try again later',
        );
      }
      appLogger.e('Charging station request failed', error: e);
      throw const StationServiceException(
        'Failed to load charging stations, please check your network and retry',
      );
    }
  }

  Map<String, dynamic> _stationToJson(Station station) => <String, dynamic>{
    'id': station.id,
    'name': station.name,
    'address': station.address,
    'tel': station.tel,
    'latitude': station.latitude,
    'longitude': station.longitude,
    'distance': station.distance,
    'category': station.category,
  };

  Station? _stationFromJson(Map<String, dynamic> json) {
    final latitude = _toDouble(json['latitude']);
    final longitude = _toDouble(json['longitude']);
    if (latitude == null || longitude == null) {
      return null;
    }
    final dynamic distance = json['distance'];
    return Station(
      id: _orText(json['id'], '').toString(),
      name: _orText(json['name'], 'Unnamed station').toString(),
      address: _orText(json['address'], '').toString(),
      tel: _orText(json['tel'], '').toString(),
      latitude: latitude,
      longitude: longitude,
      distance: _toDouble(distance),
      category: _orText(json['category'], '').toString(),
    );
  }
}

/// JS `value || fallback` 语义：null / 空串取兜底值。
dynamic _orText(dynamic value, String fallback) {
  if (value == null) {
    return fallback;
  }
  if (value is String && value.isEmpty) {
    return fallback;
  }
  return value;
}

double? _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

int? _toInt(dynamic value) {
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

final stationRepositoryProvider = Provider<StationRepository>((ref) {
  return StationRepository(
    dio: ref.watch(stationsDioProvider),
    kv: ref.watch(keyValueStoreProvider),
  );
});
