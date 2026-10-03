import 'package:ev_tool_app/core/domain/stations.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试 POI 工厂：Open Charge Map /v3/poi/ 返回的点位结构
Map<String, dynamic> mkPoi(
  String id,
  String title,
  dynamic lat,
  dynamic lng, [
  Map<String, dynamic> extra = const {},
]) => {
  'ID': id,
  'AddressInfo': {
    'Title': title,
    'AddressLine1': '1 Main St',
    'Town': 'Cupertino',
    'StateOrProvince': 'California',
    'Latitude': lat,
    'Longitude': lng,
  },
  'ContactTelephone1': '4089961010',
  'Connections': [
    {'PowerKW': 150},
  ],
  ...extra,
};

/// 测试用 station 工厂
Station mkStation(String id, double? distance) => Station(
  id: id,
  name: id,
  address: '',
  tel: '',
  latitude: 23,
  longitude: 113,
  distance: distance,
  category: '',
);

// 广州天河两个相距约 6.2km 的点（用于 haversine 校验）
const tianhe = LatLng(latitude: 23.12908, longitude: 113.26436);
const zhujiangNewTown = LatLng(latitude: 23.11812, longitude: 113.32386);

void main() {
  group('haversineDistance 球面距离', () {
    test('相同坐标返回 0', () {
      expect(haversineDistance(23.1, 113.2, 23.1, 113.2), 0);
    });

    test('对称：A→B 与 B→A 距离一致', () {
      final ab = haversineDistance(
        tianhe.latitude,
        tianhe.longitude,
        zhujiangNewTown.latitude,
        zhujiangNewTown.longitude,
      );
      final ba = haversineDistance(
        zhujiangNewTown.latitude,
        zhujiangNewTown.longitude,
        tianhe.latitude,
        tianhe.longitude,
      );
      expect((ab - ba).abs(), lessThan(1e-6));
    });

    test('纬度差 1° 约 111km', () {
      final meters = haversineDistance(23, 113, 24, 113);
      expect(meters, greaterThan(110000));
      expect(meters, lessThan(112000));
    });

    test('已知点对距离约 6.2km（±2%）', () {
      final meters = haversineDistance(
        tianhe.latitude,
        tianhe.longitude,
        zhujiangNewTown.latitude,
        zhujiangNewTown.longitude,
      );
      expect(meters, greaterThan(6100));
      expect(meters, lessThan(6300));
    });
  });

  group('formatDistance 距离格式化', () {
    for (final entry in const [
      (0, '0m'),
      (850, '850m'),
      (999, '999m'),
      (1000, '1.0km'),
      (1234, '1.2km'),
      (9560, '9.6km'),
    ]) {
      test('${entry.$1} → ${entry.$2}', () {
        expect(formatDistance(entry.$1), entry.$2);
      });
    }

    test('非法值（null/NaN）返回空字符串', () {
      expect(formatDistance(null), '');
      expect(formatDistance(double.nan), '');
    });
  });

  group('normalizeStation OCM POI 归一化', () {
    test('完整字段映射为 station 结构（距离由原点 haversine 计算）', () {
      // Arrange
      final poi = mkPoi('123', 'Apple Park Charger', 23.11812, 113.32386);

      // Act
      final station = normalizeStation(poi, tianhe);

      // Assert
      expect(station, isNotNull);
      expect(station!.id, '123');
      expect(station.name, 'Apple Park Charger');
      expect(station.address, '1 Main St, Cupertino, California');
      expect(station.tel, '4089961010');
      expect(station.latitude, 23.11812);
      expect(station.longitude, 113.32386);
      expect(station.distance, greaterThan(6100));
      expect(station.distance, lessThan(6300));
      expect(station.category, 'DC 150kW');
    });

    test('ContactTelephone1 缺失时 tel 为空串（页面据此不渲染拨打按钮）', () {
      final poi = mkPoi('poi-4', 'No Phone', 23.13, 113.27)
        ..remove('ContactTelephone1');
      expect(normalizeStation(poi, tianhe)!.tel, '');
    });

    test('Title 为空串/空值时兜底为 Unnamed station', () {
      // Arrange
      final poi = mkPoi('poi-x', '', 23.13, 113.27);

      // Act & Assert
      expect(normalizeStation(poi, tianhe)!.name, 'Unnamed station');
    });

    test('地址各部分缺失时只拼接非空部分', () {
      // Arrange
      final poi = mkPoi('poi-5', 'Bare Station', 23.13, 113.27, {
        'AddressInfo': {
          'Title': 'Bare Station',
          'Town': 'Cupertino',
          'Latitude': 23.13,
          'Longitude': 113.27,
        },
      });

      // Act & Assert
      expect(normalizeStation(poi, tianhe)!.address, 'Cupertino');
    });

    test('缺少 AddressInfo / 坐标非法 / 空入参返回 null', () {
      expect(normalizeStation({'ID': 'x'}, tianhe), isNull);
      expect(normalizeStation(null, tianhe), isNull);
      expect(
        normalizeStation({
          'ID': 'x',
          'AddressInfo': <String, dynamic>{'Title': 't'},
        }, tianhe),
        isNull,
      );
      expect(
        normalizeStation({
          'ID': 'x',
          'AddressInfo': <String, dynamic>{
            'Title': 't',
            'Latitude': 'abc',
            'Longitude': 113.27,
          },
        }, tianhe),
        isNull,
      );
    });

    test('数值字符串坐标可被容忍', () {
      final poi = mkPoi('poi-3', 'String Coord', '23.13', '113.27');
      final station = normalizeStation(poi, tianhe);
      expect(station!.latitude, 23.13);
      expect(station.longitude, 113.27);
    });

    test('category 按最大功率推导：≥50kW 为 DC，低于为 AC', () {
      // Arrange
      final dc = mkPoi('dc', 'Fast', 23.13, 113.27, {
        'Connections': [
          {'PowerKW': 11},
          {'PowerKW': 250},
        ],
      });
      final ac = mkPoi('ac', 'Slow', 23.13, 113.27, {
        'Connections': [
          {'PowerKW': 22},
        ],
      });

      // Act & Assert
      expect(normalizeStation(dc, tianhe)!.category, 'DC 250kW');
      expect(normalizeStation(ac, tianhe)!.category, 'AC 22kW');
    });

    test('无 Connections / PowerKW 全缺失时 category 为空串', () {
      // Arrange
      final noConnections = mkPoi('n1', 'Unknown', 23.13, 113.27)
        ..remove('Connections');
      final noPower = mkPoi('n2', 'No Power', 23.13, 113.27, {
        'Connections': [
          {'Quantity': 2},
        ],
      });

      // Act & Assert
      expect(normalizeStation(noConnections, tianhe)!.category, '');
      expect(normalizeStation(noPower, tianhe)!.category, '');
    });
  });

  group('sortStationsByDistance 距离排序', () {
    test('按距离升序排列且不修改原数组', () {
      // Arrange
      final far = mkStation('a', 2000);
      final near = mkStation('b', 100);
      final mid = mkStation('c', 800);
      final stations = [far, near, mid];

      // Act
      final sorted = sortStationsByDistance(stations);

      // Assert
      expect(sorted.map((s) => s.id).toList(), ['b', 'c', 'a']);
      expect(stations.map((s) => s.id).toList(), ['a', 'b', 'c']);
    });

    test('null 距离排在末尾（相等元素保持原有相对顺序）', () {
      final stations = [
        mkStation('a', null),
        mkStation('b', 50),
        mkStation('c', null),
      ];
      expect(sortStationsByDistance(stations).map((s) => s.id).toList(), [
        'b',
        'a',
        'c',
      ]);
    });

    test('空数组 / null 返回空数组', () {
      expect(sortStationsByDistance([]), isEmpty);
      expect(sortStationsByDistance(null), isEmpty);
    });
  });

  group('getCacheCell 坐标分格', () {
    test('四舍五入到 2 位小数（≈1.1km 格）', () {
      final cell = getCacheCell(
        const LatLng(latitude: 39.90923, longitude: 116.397428),
      );
      expect(cell, const CacheCell(latCell: 39.91, lngCell: 116.4));
    });

    test('同格内微差坐标得到相同 cell', () {
      final a = getCacheCell(
        const LatLng(latitude: 23.12908, longitude: 113.26436),
      );
      final b = getCacheCell(
        const LatLng(latitude: 23.12999, longitude: 113.26401),
      );
      expect(a, b);
    });

    test('跨格坐标得到不同 cell', () {
      final a = getCacheCell(
        const LatLng(latitude: 23.134, longitude: 113.264),
      );
      final b = getCacheCell(
        const LatLng(latitude: 23.136, longitude: 113.264),
      );
      expect(a.latCell, 23.13);
      expect(b.latCell, 23.14);
    });
  });

  group('isCacheFresh 缓存新鲜判定', () {
    const cell = CacheCell(latCell: 39.91, lngCell: 116.4);
    final base = StationCache(
      latCell: cell.latCell,
      lngCell: cell.lngCell,
      stations: [],
      savedAt: 1000,
    );

    test('同 cell 且未过期返回 true', () {
      expect(isCacheFresh(base, cell, 1000 + cacheTtlMs - 1), isTrue);
    });

    test('恰好到达 TTL 返回 false', () {
      expect(isCacheFresh(base, cell, 1000 + cacheTtlMs), isFalse);
    });

    test('cell 不匹配返回 false', () {
      expect(
        isCacheFresh(
          base,
          const CacheCell(latCell: 23.13, lngCell: 113.26),
          1500,
        ),
        isFalse,
      );
    });

    test('缓存为 null 返回 false', () {
      expect(isCacheFresh(null, cell, 1500), isFalse);
    });
  });

  group('rebaseStationDistances 距离重算', () {
    const origin = tianhe;

    test('按新原点重算距离且不修改原数组', () {
      // Arrange：两站原 distance 为占位值
      const stations = [
        Station(
          id: 'a',
          name: 'a',
          address: '',
          tel: '',
          latitude: 23.13,
          longitude: 113.27,
          distance: 999,
          category: '',
        ),
        Station(
          id: 'b',
          name: 'b',
          address: '',
          tel: '',
          latitude: 23.14,
          longitude: 113.28,
          distance: 888,
          category: '',
        ),
      ];

      // Act
      final rebased = rebaseStationDistances(stations, origin);

      // Assert
      expect(
        rebased[0].distance,
        haversineDistance(origin.latitude, origin.longitude, 23.13, 113.27),
      );
      expect(stations[0].distance, 999); // 原数组不变
    });

    test('空数组/null 返回空数组', () {
      expect(rebaseStationDistances([], origin), isEmpty);
      expect(rebaseStationDistances(null, origin), isEmpty);
    });
  });
}
