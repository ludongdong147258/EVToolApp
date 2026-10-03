import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/constants/env.dart';
import 'package:ev_tool_app/core/domain/stations.dart';
import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/utils/logger.dart';

/// 腾讯位置服务专用无鉴权 Dio（移植小程序 stationService 的
/// createNoAuthRequest 约束：第三方接口不注入 Bearer token，15s 超时）。
///
/// 注意：绝不复用应用的 dioProvider（带鉴权拦截器与 401 刷新链路，
/// 会把本站用户 token 发给第三方域）。
final lbsDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://apis.map.qq.com',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
});

/// 位置服务异常（页面据此渲染错误态；[isKeyMissing] 区分"Key 未配置"
/// 的专用提示，对应小程序 LBS_KEY_MISSING_CODE）。
class StationServiceException implements Exception {
  const StationServiceException(this.message, {this.isKeyMissing = false});

  final String message;
  final bool isKeyMissing;

  @override
  String toString() => message;
}

/// 配额类超限（120 每秒限流 / 121 每日配额）内部哨兵：
/// 捕获后切换备用 Key 重试，不直接透出给页面。
class _QuotaExceededException implements Exception {
  const _QuotaExceededException(this.status);

  final num status;
}

/// 逆地编码内存缓存条目（定位点属敏感信息，只存内存不落 storage）。
class _GeocodeMemo {
  const _GeocodeMemo({
    required this.latCell,
    required this.lngCell,
    required this.result,
    required this.savedAt,
  });

  final double latCell;
  final double lngCell;
  final GeocoderRegion result;
  final int savedAt;
}

/// 附近充电桩仓储（移植小程序 src/services/stationService.js）。
///
/// 封装腾讯位置服务 WebService：
/// - [searchNearbyStations]：place/search 关键词「充电桩」boundary=nearby，
///   结果按坐标分格 + 30 分钟 TTL 缓存于 KeyValueStore，命中后按当前原点
///   重算距离；
/// - [reverseGeocode]：geocoder/v1 坐标 → 省市/地址，仅内存 10 分钟缓存。
///
/// 错误策略与项目其他仓储一致：log + throw [StationServiceException]，
/// 由页面 catch 后渲染错误态。主 Key 配额超限（120/121）自动切换备用 Key。
class StationRepository {
  StationRepository({
    required Dio dio,
    required KeyValueStore kv,
    String? primaryKey,
    String? backupKey,
  }) : _dio = dio,
       _kv = kv,
       _primaryKey = primaryKey ?? Env.lbsKey,
       _backupKey = backupKey ?? Env.lbsKeyBackup;

  /// 结果缓存在本机的 key（按坐标分格 + TTL，同位置复用省配额）。
  static const String nearbyStationsCacheKey = 'nearbyStationsCache';

  /// 搜索半径（米），boundary=nearby 的上限即 1000。
  static const int _searchRadiusMeters = 1000;
  static const int _pageSize = 20;

  /// 逆地编码内存缓存有效期。
  static const int _geocodeMemoTtlMs = 10 * 60 * 1000;

  /// LBS 信封 status：每秒请求量超限 / 每日调用量超限。
  static const num _statusRateLimit = 120;
  static const num _statusDailyQuota = 121;

  static const String _quotaExceededMessage =
      'Location service daily quota reached. Please try again tomorrow or '
      'raise the quota in the Tencent LBS console';

  final Dio _dio;
  final KeyValueStore _kv;
  final String _primaryKey;
  final String _backupKey;

  _GeocodeMemo? _geocodeMemo;

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

  /// 逆地编码：坐标 → 省市/地址（充电记录自动填充地点用）。
  ///
  /// 同坐标分格（≈1.1km）10 分钟内复用内存缓存；定位点属敏感信息，
  /// 缓存只存实例字段、不落 storage。主备 Key 配额切换与搜索同款。
  Future<GeocoderRegion> reverseGeocode(double latitude, double longitude) {
    final coord = LatLng(latitude: latitude, longitude: longitude);
    final cell = getCacheCell(coord);
    final now = DateTime.now().millisecondsSinceEpoch;
    final memo = _geocodeMemo;
    final isMemoFresh =
        memo != null &&
        memo.latCell == cell.latCell &&
        memo.lngCell == cell.lngCell &&
        now - memo.savedAt < _geocodeMemoTtlMs;
    if (isMemoFresh) {
      return Future<GeocoderRegion>.value(memo.result);
    }
    return _fetchReverseGeocode(coord, cell, now);
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

  /// 请求 LBS 接口并归一化；按主 Key → 备用 Key 顺序尝试，
  /// 仅配额类超限（120/121）才切换下一个 Key，其余错误直接抛出。
  Future<List<Station>> _fetchNearbyStations(LatLng origin) async {
    final keys = _availableKeys();
    if (keys.isEmpty) {
      throw const StationServiceException(
        'Map service key not configured',
        isKeyMissing: true,
      );
    }
    return _withKeyRotation(keys, (key) => _searchOnce(origin, key));
  }

  Future<GeocoderRegion> _fetchReverseGeocode(
    LatLng coord,
    CacheCell cell,
    int now,
  ) async {
    final keys = _availableKeys();
    if (keys.isEmpty) {
      throw const StationServiceException(
        'Map service key not configured',
        isKeyMissing: true,
      );
    }
    final result = await _withKeyRotation(
      keys,
      (key) => _geocodeOnce(coord, key),
    );
    _geocodeMemo = _GeocodeMemo(
      latCell: cell.latCell,
      lngCell: cell.lngCell,
      result: result,
      savedAt: now,
    );
    return result;
  }

  /// 主备 Key 依次尝试：配额超限且还有下一个 Key 时重试，否则抛出。
  Future<T> _withKeyRotation<T>(
    List<String> keys,
    Future<T> Function(String key) action,
  ) async {
    for (var i = 0; i < keys.length; i++) {
      try {
        return await action(keys[i]);
      } on _QuotaExceededException catch (e) {
        final isLastKey = i == keys.length - 1;
        if (isLastKey) {
          throw const StationServiceException(_quotaExceededMessage);
        }
        appLogger.w(
          'Location service key quota exceeded, retrying with backup key',
          error: e,
        );
      }
    }
    // keys 非空时循环必 return / throw，此处仅为类型收口
    throw const StationServiceException(_quotaExceededMessage);
  }

  List<String> _availableKeys() => [
    for (final key in [_primaryKey, _backupKey])
      if (key.isNotEmpty) key,
  ];

  /// 用指定 Key 请求一次搜索接口并归一化（保持接口返回序，排序由调用方决定）。
  Future<List<Station>> _searchOnce(LatLng origin, String key) async {
    final body = await _getJson(
      '/ws/place/v1/search',
      queryParameters: <String, dynamic>{
        'keyword': '充电桩',
        'boundary':
            'nearby(${origin.latitude},${origin.longitude},$_searchRadiusMeters)',
        'key': key,
        'orderby': '_distance',
        'page_size': _pageSize,
      },
    );
    _throwForBusinessStatus(body);
    final dynamic pois = body['data'];
    if (pois is! List) {
      return const <Station>[];
    }
    final stations = <Station>[];
    for (final poi in pois) {
      if (poi is! Map) continue;
      final station = normalizeStation(poi.cast<String, dynamic>(), origin);
      if (station != null) stations.add(station);
    }
    return stations;
  }

  /// 用指定 Key 请求一次 geocoder 接口并归一化。
  ///
  /// 携带 get_poi=1：响应附带按距离升序的周边 POI，
  /// 地点名优先取 POI 标题（对齐小程序 chooseLocation 的 res.name 精度）。
  Future<GeocoderRegion> _geocodeOnce(LatLng coord, String key) async {
    final body = await _getJson(
      '/ws/geocoder/v1',
      queryParameters: <String, dynamic>{
        'location': '${coord.latitude},${coord.longitude}',
        'key': key,
        'get_poi': '1',
        'poi_options': 'radius=1000',
      },
    );
    final result = normalizeGeocoderResult(body);
    if (result != null) {
      final poiTitle = nearestPoiTitle(body);
      if (poiTitle == null) {
        return result;
      }
      return GeocoderRegion(
        province: result.province,
        city: result.city,
        address: result.address,
        poiTitle: poiTitle,
      );
    }
    _throwForBusinessStatus(body);
    // status 为 0 但 result 结构缺失
    throw const StationServiceException(
      'Location service error: malformed response (code 0)',
    );
  }

  /// 无鉴权 GET（LBS 接口专用）；网络失败归一化为中文 [StationServiceException]。
  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return data.cast<String, dynamic>();
      }
      // Content-Type 非 JSON 时 dio 不解码（String 原样返回），
      // 对齐 Taro.request 无论 Content-Type 都 JSON 解析的行为
      if (data is String && data.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map) {
            return decoded.cast<String, dynamic>();
          }
        } on FormatException {
          // 非 JSON 字符串 → 走空 Map，由业务状态检查统一报错
        }
      }
      return const <String, dynamic>{};
    } on DioException catch (e) {
      appLogger.e('Location service request failed', error: e);
      throw const StationServiceException(
        'Location service request failed, please check your network and retry',
      );
    }
  }

  /// LBS 信封：HTTP 200 但 status !== 0 仍是业务错误
  /// （如 key 无效 110、配额超限 120/121）。
  void _throwForBusinessStatus(Map<String, dynamic> body) {
    final dynamic status = body['status'];
    if (status is num && status == 0) {
      return;
    }
    if (status is num &&
        (status == _statusRateLimit || status == _statusDailyQuota)) {
      appLogger.w(
        'Location service returned a business error',
        error: {'status': status, 'message': body['message']},
      );
      throw _QuotaExceededException(status);
    }
    final dynamic message = body['message'];
    throw StationServiceException(
      'Location service error: ${_orText(message, 'Unknown error')} '
      '(code ${_orText(status, 'no response')})',
    );
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
    dio: ref.watch(lbsDioProvider),
    kv: ref.watch(keyValueStoreProvider),
  );
});
