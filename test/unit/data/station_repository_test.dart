import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/core/domain/stations.dart';
import 'package:ev_tool_app/features/stations/data/station_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/fake_key_value_store.dart';

const double _originLat = 23.12908;
const double _originLng = 113.26436;

Map<String, dynamic> _mkPoi(String id, String title, num lat, num lng) => {
  'type': 'node',
  'id': id,
  'lat': lat,
  'lon': lng,
  'tags': {
    'amenity': 'charging_station',
    'name': title,
    'socket:type2:output': '150 kW',
  },
};

Map<String, dynamic> _okBody(List<Map<String, dynamic>> elements) => {
  'version': 0.6,
  'generator': 'Overpass API 0.7.62',
  'elements': elements,
};

/// 注入 canned 响应的 Overpass Dio（每次请求记录 path 与 queryParameters）。
Dio _buildDio({
  required List<Map<String, dynamic>> captured,
  required ResponseBody Function(int requestIndex) respond,
}) {
  return Dio(BaseOptions(baseUrl: 'https://overpass-api.de/api'))
    ..httpClientAdapter = FakeDioAdapter((options) {
      captured.add({
        'path': options.path,
        ...options.queryParameters.cast<String, dynamic>(),
      });
      return respond(captured.length - 1);
    });
}

StationRepository _buildRepo(Dio dio, FakeKeyValueStore kv) {
  return StationRepository(dio: dio, kv: kv);
}

void main() {
  group('StationRepository 搜索缓存（Overpass）', () {
    test('未命中时请求 /interpreter 并按距离升序返回，写入缓存', () async {
      final captured = <Map<String, dynamic>>[];
      final dio = _buildDio(
        captured: captured,
        respond: (i) => jsonResponseBody(
          _okBody([
            _mkPoi('p1', 'A Station', 23.13, 113.27),
            _mkPoi('p2', 'B Station', 23.1292, 113.2645),
          ]),
        ),
      );
      final kv = FakeKeyValueStore();
      final repo = _buildRepo(dio, kv);

      final stations = await repo.searchNearbyStations(_originLat, _originLng);

      expect(captured, hasLength(1));
      expect(captured.first['path'], '/interpreter');
      // 查询携带 amenity 过滤 + around 半径 5km + 数量上限
      final query = '${captured.first['data']}';
      expect(query, contains('amenity=charging_station'));
      expect(query, contains('around:5000,$_originLat,$_originLng'));
      expect(query, contains('out tags center 30'));
      // 按距离升序（p2 更近）
      expect(stations.map((s) => s.id).toList(), ['node/p2', 'node/p1']);
      final cache = kv.getJsonMap(StationRepository.nearbyStationsCacheKey);
      expect(cache, isNotNull);
      expect(cache?['stations'], hasLength(2));
      expect(cache?['savedAt'], greaterThan(0));
    });

    test('同位置（同 cell）再次进入直接用缓存，不再请求且按新原点重算距离', () async {
      final captured = <Map<String, dynamic>>[];
      final dio = _buildDio(
        captured: captured,
        respond: (i) => jsonResponseBody(
          _okBody([_mkPoi('p1', 'A Station', 23.13, 113.27)]),
        ),
      );
      final repo = _buildRepo(dio, FakeKeyValueStore());

      await repo.searchNearbyStations(_originLat, _originLng);
      // 同 cell 内微差坐标（格内偏移）
      final stations = await repo.searchNearbyStations(23.12999, 113.26401);

      expect(captured, hasLength(1));
      expect(stations.map((s) => s.id).toList(), ['node/p1']);
      // 距离按新原点重算（与缓存内旧值不同）
      expect(stations.first.distance, isNotNull);
    });

    test('force 手动刷新绕过缓存重新请求', () async {
      final captured = <Map<String, dynamic>>[];
      final dio = _buildDio(
        captured: captured,
        respond: (i) => jsonResponseBody(
          _okBody([_mkPoi('p1', 'A Station', 23.13, 113.27)]),
        ),
      );
      final repo = _buildRepo(dio, FakeKeyValueStore());

      await repo.searchNearbyStations(_originLat, _originLng);
      await repo.searchNearbyStations(_originLat, _originLng, force: true);

      expect(captured, hasLength(2));
    });

    test('缓存过期（TTL 30 分钟）后重新请求', () async {
      final captured = <Map<String, dynamic>>[];
      final dio = _buildDio(
        captured: captured,
        respond: (i) => jsonResponseBody(
          _okBody([_mkPoi('p1', 'A Station', 23.13, 113.27)]),
        ),
      );
      final kv = FakeKeyValueStore();
      final repo = _buildRepo(dio, kv);

      await repo.searchNearbyStations(_originLat, _originLng);
      final cache = kv.getJsonMap(StationRepository.nearbyStationsCacheKey);
      await kv.setJson(StationRepository.nearbyStationsCacheKey, {
        ...cache ?? <String, dynamic>{},
        'savedAt': DateTime.now().millisecondsSinceEpoch - cacheTtlMs - 1,
      });

      await repo.searchNearbyStations(_originLat, _originLng);

      expect(captured, hasLength(2));
    });

    test('跨位置（不同 cell）不使用缓存', () async {
      final captured = <Map<String, dynamic>>[];
      final dio = _buildDio(
        captured: captured,
        respond: (i) => jsonResponseBody(
          _okBody([_mkPoi('p1', 'A Station', 23.13, 113.27)]),
        ),
      );
      final repo = _buildRepo(dio, FakeKeyValueStore());

      await repo.searchNearbyStations(_originLat, _originLng);
      // 纬度跨格（23.11 → cell 23.11 ≠ 23.13）
      await repo.searchNearbyStations(23.11, 113.264);

      expect(captured, hasLength(2));
    });

    test('空 elements 响应返回空列表且照常写入缓存', () async {
      final captured = <Map<String, dynamic>>[];
      final dio = _buildDio(
        captured: captured,
        respond: (i) => jsonResponseBody(_okBody([])),
      );
      final kv = FakeKeyValueStore();
      final repo = _buildRepo(dio, kv);

      final stations = await repo.searchNearbyStations(_originLat, _originLng);

      expect(stations, isEmpty);
      expect(
        kv.getJsonMap(StationRepository.nearbyStationsCacheKey)?['stations'],
        isEmpty,
      );
    });
  });

  group('StationRepository 错误处理', () {
    test('HTTP 429/504（Overpass 限流/过载）抛「服务繁忙」', () async {
      for (final statusCode in [429, 504]) {
        final captured = <Map<String, dynamic>>[];
        final dio = _buildDio(
          captured: captured,
          respond: (i) => jsonResponseBody({}, status: statusCode),
        );
        final repo = _buildRepo(dio, FakeKeyValueStore());

        await expectLater(
          repo.searchNearbyStations(_originLat, _originLng),
          throwsA(
            isA<StationServiceException>().having(
              (e) => e.message,
              'message',
              contains('busy'),
            ),
          ),
        );
      }
    });

    test('网络失败等其他 DioException 抛网络错误提示', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://overpass-api.de/api'))
        ..httpClientAdapter = FakeDioAdapter((options) {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'connection error',
          );
        });
      final repo = _buildRepo(dio, FakeKeyValueStore());

      await expectLater(
        repo.searchNearbyStations(_originLat, _originLng),
        throwsA(
          isA<StationServiceException>().having(
            (e) => e.message,
            'message',
            contains('network'),
          ),
        ),
      );
    });

    test('200 但非 JSON body（如 HTML 页面）按空结果处理', () async {
      final dio = _buildDio(
        captured: [],
        respond: (i) => textResponseBody('<html>blocked</html>'),
      );
      final kv = FakeKeyValueStore();
      final repo = _buildRepo(dio, kv);

      final stations = await repo.searchNearbyStations(_originLat, _originLng);

      expect(stations, isEmpty);
    });
  });
}
