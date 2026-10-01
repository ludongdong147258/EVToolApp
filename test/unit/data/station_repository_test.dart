import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/core/domain/stations.dart';
import 'package:ev_tool_app/features/stations/data/station_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/fake_key_value_store.dart';

const double _originLat = 23.12908;
const double _originLng = 113.26436;

Map<String, dynamic> _okBody(List<Map<String, dynamic>> pois) => {
  'status': 0,
  'data': pois,
};

Map<String, dynamic> _errBody(num status, [String message = '请求配额超限']) => {
  'status': status,
  'message': message,
};

Map<String, dynamic> _mkPoi(
  String id,
  String title,
  num lat,
  num lng,
  num distance,
) => {
  'id': id,
  'title': title,
  'address': '$title地址',
  'tel': '',
  'location': {'lat': lat, 'lng': lng},
  '_distance': distance,
  'category': '充电桩',
};

/// 注入 canned 响应的 LBS Dio（每次请求记录 queryParameters，供断言 Key 轮换）。
Dio _buildDio({
  required List<Map<String, dynamic>> captured,
  required Map<String, dynamic> Function(int requestIndex) respond,
}) {
  return Dio(BaseOptions(baseUrl: 'https://apis.map.qq.com'))
    ..httpClientAdapter = FakeDioAdapter((options) {
      captured.add(options.queryParameters.cast<String, dynamic>());
      return jsonResponseBody(respond(captured.length - 1));
    });
}

StationRepository _buildRepo(Dio dio, FakeKeyValueStore kv) {
  return StationRepository(
    dio: dio,
    kv: kv,
    primaryKey: 'TEST_KEY',
    backupKey: 'BACKUP_KEY',
  );
}

void main() {
  group('StationRepository 搜索缓存（移植 stationService.test.js）', () {
    test('未命中时请求接口并按距离升序返回，写入缓存', () async {
      final captured = <Map<String, dynamic>>[];
      final dio = _buildDio(
        captured: captured,
        respond: (i) => _okBody([
          _mkPoi('p1', 'A 站', 23.13, 113.27, 300),
          _mkPoi('p2', 'B 站', 23.14, 113.28, 100),
        ]),
      );
      final kv = FakeKeyValueStore();
      final repo = _buildRepo(dio, kv);

      final stations = await repo.searchNearbyStations(_originLat, _originLng);

      expect(captured, hasLength(1));
      expect(captured.first['keyword'], '充电桩');
      expect(captured.first['boundary'], 'nearby(23.12908,113.26436,1000)');
      expect(captured.first['orderby'], '_distance');
      expect(captured.first['page_size'], 20);
      // 按距离升序
      expect(stations.map((s) => s.id).toList(), ['p2', 'p1']);
      final cache = kv.getJsonMap(StationRepository.nearbyStationsCacheKey);
      expect(cache, isNotNull);
      expect(cache?['stations'], hasLength(2));
      expect(cache?['savedAt'], greaterThan(0));
    });

    test('同位置（同 cell）再次进入直接用缓存，不再请求且按新原点重算距离', () async {
      final captured = <Map<String, dynamic>>[];
      final dio = _buildDio(
        captured: captured,
        respond: (i) => _okBody([_mkPoi('p1', 'A 站', 23.13, 113.27, 100)]),
      );
      final repo = _buildRepo(dio, FakeKeyValueStore());

      await repo.searchNearbyStations(_originLat, _originLng);
      // 同 cell 内微差坐标（格内偏移）
      final stations = await repo.searchNearbyStations(23.12999, 113.26401);

      expect(captured, hasLength(1));
      expect(stations.map((s) => s.id).toList(), ['p1']);
      // 距离按新原点重算（与缓存内旧值不同）
      expect(stations.first.distance, isNot(100));
    });

    test('force 手动刷新绕过缓存重新请求', () async {
      final captured = <Map<String, dynamic>>[];
      final dio = _buildDio(
        captured: captured,
        respond: (i) => _okBody([_mkPoi('p1', 'A 站', 23.13, 113.27, 100)]),
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
        respond: (i) => _okBody([_mkPoi('p1', 'A 站', 23.13, 113.27, 100)]),
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
        respond: (i) => _okBody([_mkPoi('p1', 'A 站', 23.13, 113.27, 100)]),
      );
      final repo = _buildRepo(dio, FakeKeyValueStore());

      await repo.searchNearbyStations(_originLat, _originLng);
      // 纬度跨格（23.11 → cell 23.11 ≠ 23.13）
      await repo.searchNearbyStations(23.11, 113.264);

      expect(captured, hasLength(2));
    });

    test('Key 未配置时抛「未配置地图服务 Key」', () async {
      final captured = <Map<String, dynamic>>[];
      final dio = _buildDio(captured: captured, respond: (i) => _okBody([]));
      final repo = StationRepository(
        dio: dio,
        kv: FakeKeyValueStore(),
        primaryKey: '',
        backupKey: '',
      );

      await expectLater(
        repo.searchNearbyStations(_originLat, _originLng),
        throwsA(
          isA<StationServiceException>()
              .having((e) => e.isKeyMissing, 'isKeyMissing', isTrue)
              .having((e) => e.message, 'message', '未配置地图服务 Key'),
        ),
      );
      expect(captured, isEmpty);
    });
  });

  group('StationRepository 备用 Key 自动切换', () {
    test('主 Key 每日配额超限（121）时用备用 Key 重试成功', () async {
      final captured = <Map<String, dynamic>>[];
      final dio = _buildDio(
        captured: captured,
        respond: (i) => i == 0
            ? _errBody(121)
            : _okBody([_mkPoi('p1', 'A 站', 23.13, 113.27, 100)]),
      );
      final repo = _buildRepo(dio, FakeKeyValueStore());

      final stations = await repo.searchNearbyStations(_originLat, _originLng);

      expect(captured, hasLength(2));
      expect(captured.first['key'], 'TEST_KEY');
      expect(captured.last['key'], 'BACKUP_KEY');
      expect(stations.map((s) => s.id).toList(), ['p1']);
    });

    test('主 Key 每秒限流（120）时同样切换备用 Key', () async {
      final captured = <Map<String, dynamic>>[];
      final dio = _buildDio(
        captured: captured,
        respond: (i) => i == 0
            ? _errBody(120)
            : _okBody([_mkPoi('p1', 'A 站', 23.13, 113.27, 100)]),
      );
      final repo = _buildRepo(dio, FakeKeyValueStore());

      final stations = await repo.searchNearbyStations(_originLat, _originLng);

      expect(captured, hasLength(2));
      expect(captured.last['key'], 'BACKUP_KEY');
      expect(stations.map((s) => s.id).toList(), ['p1']);
    });

    test('主、备 Key 均配额超限时抛中文配额错误', () async {
      final captured = <Map<String, dynamic>>[];
      final dio = _buildDio(captured: captured, respond: (i) => _errBody(121));
      final repo = _buildRepo(dio, FakeKeyValueStore());

      await expectLater(
        repo.searchNearbyStations(_originLat, _originLng),
        throwsA(
          isA<StationServiceException>().having(
            (e) => e.message,
            'message',
            contains('今日位置服务调用次数已达上限'),
          ),
        ),
      );
      expect(captured, hasLength(2));
    });

    test('非配额业务错误（如 key 无效 110）不重试备用 Key', () async {
      final captured = <Map<String, dynamic>>[];
      final dio = _buildDio(
        captured: captured,
        respond: (i) => _errBody(110, '请求来源未被授权'),
      );
      final repo = _buildRepo(dio, FakeKeyValueStore());

      await expectLater(
        repo.searchNearbyStations(_originLat, _originLng),
        throwsA(
          isA<StationServiceException>().having(
            (e) => e.message,
            'message',
            contains('位置服务错误'),
          ),
        ),
      );
      expect(captured, hasLength(1));
    });
  });

  group('StationRepository 逆地编码', () {
    Map<String, dynamic> geocodeBody({String city = '广州市'}) => {
      'status': 0,
      'result': {
        'address': '天河路123号',
        'address_component': {'province': '广东省', 'city': city},
        'formatted_addresses': {'recommend': '广东省广州市天河区天河路123号'},
      },
    };

    test('归一化返回省市与推荐地址', () async {
      final captured = <Map<String, dynamic>>[];
      final dio = _buildDio(captured: captured, respond: (i) => geocodeBody());
      final repo = _buildRepo(dio, FakeKeyValueStore());

      final region = await repo.reverseGeocode(_originLat, _originLng);

      expect(captured, hasLength(1));
      expect(captured.first['location'], '$_originLat,$_originLng');
      expect(region.province, '广东省');
      expect(region.city, '广州市');
      expect(region.address, '广东省广州市天河区天河路123号');
    });

    test('直辖市 city 为空时用 province 补位', () async {
      final captured = <Map<String, dynamic>>[];
      final dio = _buildDio(
        captured: captured,
        respond: (i) => geocodeBody(city: ''),
      );
      final repo = _buildRepo(dio, FakeKeyValueStore());

      final region = await repo.reverseGeocode(_originLat, _originLng);

      expect(region.city, region.province);
      expect(region.city, '广东省');
    });

    test('同坐标 10 分钟内复用内存缓存，不再请求', () async {
      final captured = <Map<String, dynamic>>[];
      final dio = _buildDio(captured: captured, respond: (i) => geocodeBody());
      final kv = FakeKeyValueStore();
      final repo = _buildRepo(dio, kv);

      await repo.reverseGeocode(_originLat, _originLng);
      // 格内微差坐标，同 cell 命中内存 memo
      await repo.reverseGeocode(23.12999, 113.26401);

      expect(captured, hasLength(1));
      // 敏感信息不落 storage
      expect(kv.getJson(StationRepository.nearbyStationsCacheKey), isNull);
    });
  });
}
