import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/core/domain/charge_map.dart';
import 'package:ev_tool_app/core/domain/charge_records.dart';

ChargeRecord _record(Map<String, dynamic> overrides) {
  return ChargeRecord.fromJson({
    'id': 'r1',
    'type': 'fast',
    'date': '2026-08-01',
    'cost': 30,
    'energy': 40,
    'latitude': 30.274,
    'longitude': 120.155,
    'createdAt': 1,
    ...overrides,
  });
}

LocationGroup _group({
  required String key,
  required double latitude,
  required double longitude,
  required int homeCount,
  required int fastCount,
  required String locationName,
  required int count,
}) {
  return LocationGroup(
    key: key,
    latitude: latitude,
    longitude: longitude,
    locationName: locationName,
    city: locationName,
    province: null,
    count: count,
    homeCount: homeCount,
    fastCount: fastCount,
    totalCost: 0,
    totalEnergy: 0,
    records: const [],
  );
}

void main() {
  group('getCityCoord 城市坐标查询', () {
    test('全称匹配（选择器口径）', () {
      expect(getCityCoord('浙江省', '杭州市')!.lat, closeTo(30.274, 1e-9));
      expect(getCityCoord('浙江省', '杭州市')!.lng, closeTo(120.155, 1e-9));
      expect(getCityCoord('北京市', '北京市')!.lat, closeTo(39.904, 1e-9));
      expect(getCityCoord('北京市', '北京市')!.lng, closeTo(116.407, 1e-9));
    });

    test('简称与后缀剥离匹配', () {
      expect(getCityCoord('广东省', '广州')!.lat, closeTo(23.129, 1e-9));
      expect(getCityCoord('广东省', '广州')!.lng, closeTo(113.264, 1e-9));
      expect(getCityCoord('湖北省', '恩施土家族苗族自治州')!.lat, closeTo(30.272, 1e-9));
      expect(getCityCoord('湖北省', '恩施土家族苗族自治州')!.lng, closeTo(109.488, 1e-9));
    });

    test('省或城市未收录返回 null', () {
      expect(getCityCoord('浙江省', '不存在市'), isNull);
      expect(getCityCoord('火星省', '杭州'), isNull);
    });
  });

  group('findNearestCity 最近城市', () {
    test('坐标落在杭州附近返回杭州', () {
      final hit = findNearestCity(30.3, 120.1);
      expect(hit, isNotNull);
      expect(hit!.city, '杭州');
      expect(hit.province, '浙江省');
    });

    test('与 matchCity 口径一致（选择器全称与地图选点归一到同一简称）', () {
      expect(matchCity('浙江省', '杭州市'), '杭州');
      expect(matchCity('湖北省', '恩施土家族苗族自治州'), '恩施');
      expect(matchCity('广东省', '广州'), '广州');
      expect(matchCity('浙江省', '不存在市'), isNull);
    });

    test('非法坐标返回 null', () {
      expect(findNearestCity(null, 120), isNull);
      expect(findNearestCity(null, null), isNull);
    });
  });

  group('groupRecordsByLocation 点位聚合', () {
    test('同城市同地点名聚合为一组并统计类型/花费', () {
      // Arrange
      final records = [
        _record({
          'id': 'r1',
          'type': 'fast',
          'cost': 30,
          'energy': 40,
          'city': '杭州',
          'locationName': '服务区快充',
        }),
        _record({
          'id': 'r2',
          'type': 'home',
          'cost': 10,
          'energy': 20,
          'city': '杭州',
          'locationName': '服务区快充',
        }),
        _record({
          'id': 'r3',
          'type': 'fast',
          'cost': 25,
          'energy': 30,
          'city': '上海',
          'locationName': '商场充电站',
        }),
      ];

      // Act
      final groups = groupRecordsByLocation(records);

      // Assert
      expect(groups, hasLength(2));
      final top = groups.first; // 杭州组 2 次最多
      expect(top.count, 2);
      expect(top.homeCount, 1);
      expect(top.fastCount, 1);
      expect(top.totalCost, 40);
      expect(top.totalEnergy, 60);
      expect(top.records.map((r) => r.id).toList(), ['r1', 'r2']);
    });

    test('无地点名的记录按城市充电点聚合', () {
      // Arrange
      final records = [
        _record({'city': '杭州', 'locationName': null}),
        _record({'city': '杭州', 'locationName': ''}),
      ];

      // Act & Assert
      final groups = groupRecordsByLocation(records);
      expect(groups, hasLength(1));
      expect(groups.first.locationName, cityPointName);
    });

    test('无经纬度的记录被忽略', () {
      // Arrange & Act
      final groups = groupRecordsByLocation([
        _record({'latitude': null, 'longitude': null}),
        _record({'latitude': null, 'longitude': null}),
      ]);

      // Assert
      expect(groups, isEmpty);
    });
  });

  group('buildLocationMarkers 标记构建', () {
    final groups = [
      _group(
        key: 'k1',
        latitude: 30.2,
        longitude: 120.1,
        homeCount: 3,
        fastCount: 1,
        locationName: 'A',
        count: 4,
      ),
      _group(
        key: 'k2',
        latitude: 31.2,
        longitude: 121.4,
        homeCount: 0,
        fastCount: 5,
        locationName: 'B',
        count: 5,
      ),
      _group(
        key: 'k3',
        latitude: 39.9,
        longitude: 116.4,
        homeCount: 2,
        fastCount: 2,
        locationName: 'C',
        count: 4,
      ),
    ];

    test('marker id 为数组下标，家充为主用绿点、否则橙点', () {
      // Act
      final markers = buildLocationMarkers(groups);

      // Assert
      expect(markers.map((m) => m.id).toList(), [0, 1, 2]);
      expect(markers[0].isHome, isTrue);
      expect(markers[1].isHome, isFalse);
      expect(markers[2].isHome, isFalse); // 平局归快充
    });

    test('同坐标点位散开（偏移半径 scatterRadiusDeg），单点不偏移', () {
      // Arrange：k1/k2 同坐标，k3 独立
      final coincident = [
        _group(
          key: 'k1',
          latitude: 30.2,
          longitude: 120.1,
          homeCount: 3,
          fastCount: 1,
          locationName: 'A',
          count: 4,
        ),
        _group(
          key: 'k2',
          latitude: 30.2,
          longitude: 120.1,
          homeCount: 0,
          fastCount: 5,
          locationName: 'B',
          count: 5,
        ),
        groups[2],
      ];

      // Act
      final markers = buildLocationMarkers(coincident);

      // Assert：k3 精确压在原坐标；k1/k2 围绕原坐标散开且互不相同
      expect(markers[2].latitude, 39.9);
      expect(markers[2].longitude, 116.4);
      final pairDist = _hypot(
        markers[0].latitude - markers[1].latitude,
        (markers[0].longitude - markers[1].longitude) *
            math.cos(30.2 * math.pi / 180),
      );
      expect(pairDist, greaterThan(0));
      for (final i in [0, 1]) {
        final latDiff = markers[i].latitude - 30.2;
        final lngDiff = markers[i].longitude - 120.1;
        final offset = _hypot(latDiff, lngDiff);
        expect(offset, lessThan(scatterRadiusDeg + 1e-9));
        expect(offset, greaterThan(0));
      }
    });

    test('选中点位放大并带品牌样式 callout（地名 + 次数）', () {
      // Act
      final markers = buildLocationMarkers(groups, selectedKey: 'k2');

      // Assert
      expect(markers[0].calloutText, isNull);
      expect(markers[0].isSelected, isFalse);
      expect(markers[1].isSelected, isTrue);
      expect(markers[1].calloutText, 'B · 5次');
    });

    test('空数组输入返回空数组', () {
      expect(buildLocationMarkers(const []), isEmpty);
    });
  });

  group('calcCityTop 高频城市', () {
    test('按城市计数降序取前 N', () {
      // Arrange
      final records = [
        _record({'city': '杭州'}),
        _record({'city': '杭州'}),
        _record({'city': '杭州'}),
        _record({'city': '上海'}),
        _record({'city': '上海'}),
        _record({'city': '北京'}),
        _record({'city': null}),
      ];

      // Act & Assert
      expect(calcCityTop(records, 3), [
        predicate<({String city, int count})>(
          (e) => e.city == '杭州' && e.count == 3,
        ),
        predicate<({String city, int count})>(
          (e) => e.city == '上海' && e.count == 2,
        ),
        predicate<({String city, int count})>(
          (e) => e.city == '北京' && e.count == 1,
        ),
      ]);
      expect(calcCityTop(records, 1).single.city, '杭州');
    });

    test('无城市记录返回空数组', () {
      expect(
        calcCityTop([
          _record({'city': null}),
        ], 3),
        isEmpty,
      );
    });
  });

  group('calcLocationStats 点位统计', () {
    test('统计有地点记录的家充/快充占比', () {
      // Arrange：6 条有地点（4 家充 2 快充）+ 2 条无地点（不计入）
      final records = [
        _record({'type': 'home'}),
        _record({'type': 'home'}),
        _record({'type': 'home'}),
        _record({'type': 'home'}),
        _record({'type': 'fast'}),
        _record({'type': 'fast'}),
        _record({'type': 'home', 'latitude': null, 'longitude': null}),
        _record({'type': 'fast', 'latitude': null, 'longitude': null}),
      ];

      // Act
      final stats = calcLocationStats(records);

      // Assert
      expect(stats.recordCount, 6);
      expect(stats.homeCount, 4);
      expect(stats.fastCount, 2);
      expect(stats.homeRatio, 67);
      expect(stats.fastRatio, 33);
    });

    test('无记录时全部为 0', () {
      final stats = calcLocationStats([]);
      expect(stats.recordCount, 0);
      expect(stats.homeCount, 0);
      expect(stats.fastCount, 0);
      expect(stats.homeRatio, 0);
      expect(stats.fastRatio, 0);
    });
  });

  group('getMapCenter 地图初始视野（fit-all）', () {
    test('单点位：该点坐标 + 城市视野', () {
      // Arrange
      final records = [
        _record({'city': '杭州', 'locationName': '家充'}),
        _record({'city': '杭州', 'locationName': '家充'}),
      ];

      // Act & Assert
      final viewport = getMapCenter(
        records,
        fallbackLatitude: 39.9,
        fallbackLongitude: 116.4,
      );
      expect(viewport.latitude, closeTo(30.274, 1e-9));
      expect(viewport.longitude, closeTo(120.155, 1e-9));
      expect(viewport.zoom, 11);
    });

    test('跨城市多点位：中心在包围盒几何中心，缩放足够宽（杭州 ↔ 北京）', () {
      // Arrange
      final records = [
        _record({
          'id': 'r1',
          'latitude': 30.274,
          'longitude': 120.155,
          'locationName': '家充',
        }),
        _record({
          'id': 'r2',
          'latitude': 39.904,
          'longitude': 116.407,
          'locationName': '商场快充',
        }),
      ];

      // Act
      final viewport = getMapCenter(
        records,
        fallbackLatitude: 39.9,
        fallbackLongitude: 116.4,
      );

      // Assert：中心为两点中点，zoom 为宽视野（375×350 视口下约 4）
      expect(viewport.latitude, closeTo((30.274 + 39.904) / 2, 1e-6));
      expect(viewport.longitude, closeTo((120.155 + 116.407) / 2, 1e-6));
      expect(viewport.zoom, greaterThanOrEqualTo(4));
      expect(viewport.zoom, lessThanOrEqualTo(6));
    });

    test('同城近距多点位：缩放收敛到上限 14 附近不无限放大', () {
      // Arrange：相距约 3km 的两个点
      final records = [
        _record({
          'id': 'r1',
          'latitude': 30.274,
          'longitude': 120.155,
          'locationName': '家充',
        }),
        _record({
          'id': 'r2',
          'latitude': 30.3,
          'longitude': 120.17,
          'locationName': '服务区快充',
        }),
      ];

      // Act
      final viewport = getMapCenter(
        records,
        fallbackLatitude: 39.9,
        fallbackLongitude: 116.4,
      );

      // Assert
      expect(viewport.zoom, greaterThanOrEqualTo(12));
      expect(viewport.zoom, lessThanOrEqualTo(14));
    });

    test('无点位记录时用兜底坐标小比例尺', () {
      final viewport = getMapCenter(
        [],
        fallbackLatitude: 39.9,
        fallbackLongitude: 116.4,
      );
      expect(viewport.latitude, 39.9);
      expect(viewport.longitude, 116.4);
      expect(viewport.zoom, 4);
    });
  });
}

double _hypot(double a, double b) => math.sqrt(a * a + b * b);
