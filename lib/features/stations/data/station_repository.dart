import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/stations.dart';
import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/utils/logger.dart';

/// Overpass (OpenStreetMap) 专用无鉴权 Dio（沿用小程序 createNoAuthRequest
/// 约束：第三方接口不注入 Bearer token；Overpass 查询较重，超时放到 30s）。
///
/// 注意：绝不复用应用的 dioProvider（带鉴权拦截器与 401 刷新链路，
/// 会把本站用户 token 发给第三方域）。
final stationsDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://overpass-api.de/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
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

/// 附近充电桩仓储（数据源 OpenStreetMap Overpass API）。
///
/// - `nwr[amenity=charging_station]` around 半径 5km（海外桩密度低），
///   最多 30 条；
/// - 结果按坐标分格 + 30 分钟 TTL 缓存于 KeyValueStore，命中后按当前
///   原点重算距离；
/// - Overpass 是公共共享服务：带 Accept/UA 头礼貌请求，429/504 限流
///   归一为「服务繁忙」；
/// - 错误策略与项目其他仓储一致：log + throw [StationServiceException]，
///   由页面 catch 后渲染错误态。
class StationRepository {
  StationRepository({required Dio dio, required KeyValueStore kv})
    : _dio = dio,
      _kv = kv;

  /// 结果缓存在本机的 key（按坐标分格 + TTL，同位置复用）。
  static const String nearbyStationsCacheKey = 'nearbyStationsCache';

  /// 搜索半径（米）——海外充电桩密度远低于国内，1km 常返回空。
  static const int _searchRadiusMeters = 5000;
  static const int _maxResults = 30;
  static const int _overpassTimeoutSeconds = 20;

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

  /// 请求 Overpass /interpreter 并归一化（保持接口返回序，排序由调用方决定）。
  Future<List<Station>> _fetchNearbyStations(LatLng origin) async {
    final query =
        '[out:json][timeout:$_overpassTimeoutSeconds];'
        'nwr[amenity=charging_station]'
        '(around:$_searchRadiusMeters,${origin.latitude},${origin.longitude});'
        'out tags center $_maxResults;';
    final body = await _getJson('/interpreter', query);
    final dynamic elements = body['elements'];
    if (elements is! List) {
      return const <Station>[];
    }
    final stations = <Station>[];
    for (final element in elements) {
      if (element is! Map) continue;
      final station = normalizeStation(element.cast<String, dynamic>(), origin);
      if (station != null) stations.add(station);
    }
    return stations;
  }

  /// 无鉴权 GET（Overpass 专用）。Accept/UA 头必须带（裸请求会 406）。
  /// 网络失败 / 限流（429/504）归一化为 [StationServiceException]。
  Future<Map<String, dynamic>> _getJson(String path, String query) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: <String, dynamic>{'data': query},
        options: Options(
          headers: <String, dynamic>{
            'Accept': 'application/json',
            'User-Agent': 'VoltLedger/1.0',
          },
        ),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return data.cast<String, dynamic>();
      }
      // Content-Type 非 JSON 时 dio 不解码（String 原样返回），手动解析
      if (data is String && data.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map) {
            return decoded.cast<String, dynamic>();
          }
        } on FormatException {
          // 非 JSON 字符串 → 走空 Map，elements 缺失按空结果处理
        }
      }
      return const <String, dynamic>{};
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final isBusy = statusCode == 429 || statusCode == 504;
      if (isBusy) {
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
