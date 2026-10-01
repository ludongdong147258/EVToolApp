import 'package:ev_tool_app/core/domain/stations.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试 POI 工厂：腾讯位置服务 place/search 返回的点位结构
Map<String, dynamic> mkPoi(
  String id,
  String title,
  dynamic lat,
  dynamic lng, [
  Map<String, dynamic> extra = const {},
]) => {
  'id': id,
  'title': title,
  'address': '$title地址',
  'tel': '4006860400',
  'location': {'lat': lat, 'lng': lng},
  '_distance': 500,
  'category': '充电桩',
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

  group('normalizeStation POI 归一化', () {
    test('完整字段映射为 station 结构', () {
      // Arrange
      final poi = mkPoi('poi-1', '天河充电站', 23.13, 113.27);

      // Act
      final station = normalizeStation(poi, tianhe);

      // Assert
      expect(station, isNotNull);
      expect(station!.id, 'poi-1');
      expect(station.name, '天河充电站');
      expect(station.address, '天河充电站地址');
      expect(station.tel, '4006860400');
      expect(station.latitude, 23.13);
      expect(station.longitude, 113.27);
      expect(station.distance, 500);
      expect(station.category, '充电桩');
    });

    test('tel 缺失时返回空串（页面据此不渲染拨打按钮）', () {
      final poi = mkPoi('poi-4', '无电话站', 23.13, 113.27, {'tel': ''});
      expect(normalizeStation(poi, tianhe)!.tel, '');
    });

    test('缺少 location 返回 null', () {
      expect(normalizeStation({'id': 'x', 'title': 't'}, tianhe), isNull);
      expect(
        normalizeStation({
          'id': 'x',
          'title': 't',
          'location': <String, dynamic>{},
        }, tianhe),
        isNull,
      );
      expect(normalizeStation(null, tianhe), isNull);
    });

    test('_distance 缺失时用 haversine 基于原点重算', () {
      // Arrange
      final poi = mkPoi(
        'poi-2',
        '珠江新城站',
        zhujiangNewTown.latitude,
        zhujiangNewTown.longitude,
      )..remove('_distance');

      // Act
      final station = normalizeStation(poi, tianhe);

      // Assert
      expect(station!.distance, greaterThan(6100));
      expect(station.distance, lessThan(6300));
    });

    test('数值字符串坐标可被容忍', () {
      final poi = mkPoi('poi-3', '字符串坐标站', '23.13', '113.27');
      final station = normalizeStation(poi, tianhe);
      expect(station!.latitude, 23.13);
      expect(station.longitude, 113.27);
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

  group('buildMapMarkers 地图 marker 构建', () {
    const icon = 'data:image/png;base64,normal';
    const activeIcon = 'data:image/png;base64,active';
    const stations = [
      Station(
        id: 'poi-1',
        name: 'A 站',
        address: '',
        tel: '',
        latitude: 23.13,
        longitude: 113.27,
        distance: 100,
        category: '',
      ),
      Station(
        id: 'poi-2',
        name: 'B 站',
        address: '',
        tel: '',
        latitude: 23.14,
        longitude: 113.28,
        distance: 300,
        category: '',
      ),
    ];

    test('marker id 为从 0 开始的唯一数字（weapp 要求）', () {
      final markers = buildMapMarkers(
        stations,
        selectedId: null,
        iconPath: icon,
        activeIconPath: activeIcon,
      );
      expect(markers.map((m) => m.id).toList(), [0, 1]);
      expect(markers[0].latitude, 23.13);
      expect(markers[0].longitude, 113.27);
    });

    test('圆形徽章锚点居中，压在坐标点上', () {
      final markers = buildMapMarkers(
        stations,
        selectedId: null,
        iconPath: icon,
        activeIconPath: activeIcon,
      );
      expect(markers[0].anchorX, 0.5);
      expect(markers[0].anchorY, 0.5);
    });

    test('选中站点使用激活图标并带品牌样式常显 callout', () {
      final markers = buildMapMarkers(
        stations,
        selectedId: 'poi-2',
        iconPath: icon,
        activeIconPath: activeIcon,
      );
      expect(markers[0].iconPath, icon);
      expect(markers[1].iconPath, activeIcon);
      final callout = markers[1].callout;
      expect(callout, isNotNull);
      expect(callout!.content, 'B 站');
      expect(callout.display, 'ALWAYS');
      expect(callout.bgColor, '#059669');
      expect(callout.color, '#FFFFFF');
      expect(markers[0].callout, isNull);
    });

    test('空列表与 null 返回空数组', () {
      expect(
        buildMapMarkers(
          [],
          selectedId: null,
          iconPath: icon,
          activeIconPath: activeIcon,
        ),
        isEmpty,
      );
      expect(
        buildMapMarkers(
          null,
          selectedId: null,
          iconPath: icon,
          activeIconPath: activeIcon,
        ),
        isEmpty,
      );
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

  group('normalizeGeocoderResult 逆地编码归一化', () {
    Map<String, dynamic> mkBody(
      Map<String, dynamic> result, [
      dynamic status = 0,
    ]) => {'status': status, 'result': result};

    test('正常响应取行政区与推荐地址', () {
      // Arrange
      final body = mkBody({
        'address': '浙江省杭州市西湖区文三路138号',
        'formatted_addresses': {'recommend': '浙江省杭州市西湖区文三路'},
        'address_component': {
          'province': '浙江省',
          'city': '杭州市',
          'district': '西湖区',
        },
      });

      // Act & Assert
      expect(normalizeGeocoderResult(body), isNotNull);
      expect(normalizeGeocoderResult(body)!.province, '浙江省');
      expect(normalizeGeocoderResult(body)!.city, '杭州市');
      expect(normalizeGeocoderResult(body)!.address, '浙江省杭州市西湖区文三路');
    });

    test('无推荐地址时兜底 result.address', () {
      // Arrange
      final body = mkBody({
        'address': '广东省广州市天河区天河路1号',
        'address_component': {
          'province': '广东省',
          'city': '广州市',
          'district': '天河区',
        },
      });

      // Act & Assert
      expect(normalizeGeocoderResult(body)!.address, '广东省广州市天河区天河路1号');
    });

    test('直辖市 city 为空串时用 province 补位', () {
      // Arrange
      final body = mkBody({
        'address': '北京市东城区正义路2号',
        'address_component': {'province': '北京市', 'city': '', 'district': '东城区'},
      });

      // Act & Assert
      final region = normalizeGeocoderResult(body);
      expect(region, isNotNull);
      expect(region!.province, '北京市');
      expect(region.city, '北京市');
      expect(region.address, '北京市东城区正义路2号');
    });

    test('status 非 0 / 结构缺失 / 空入参返回 null', () {
      // Arrange & Act & Assert
      expect(normalizeGeocoderResult(mkBody({}, 110)), isNull);
      expect(
        normalizeGeocoderResult(mkBody(<String, dynamic>{'address': 'x'})),
        isNull,
      );
      expect(normalizeGeocoderResult(null), isNull);
    });
  });
}
