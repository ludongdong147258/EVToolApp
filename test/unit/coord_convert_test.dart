import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/core/utils/coord_convert.dart';

void main() {
  group('wgs84ToGcj02', () {
    test('国界外坐标原样返回', () {
      final point = wgs84ToGcj02(40.7128, -74.0060); // 纽约
      expect(point.latitude, 40.7128);
      expect(point.longitude, -74.0060);
    });

    test('北京坐标偏移在合理量级（< 1km）', () {
      const wgsLat = 39.9042;
      const wgsLng = 116.4074;
      final point = wgs84ToGcj02(wgsLat, wgsLng);
      // GCJ-02 相对 WGS-84 在中国境内偏移约 300-700m
      final latDiff = (point.latitude - wgsLat).abs() * 111000; // 纬度 1° ≈ 111km
      final lngDiff =
          (point.longitude - wgsLng).abs() * 111000 * 0.77; // 北京纬度经度 1° ≈ 85km
      expect(latDiff, greaterThan(100));
      expect(latDiff, lessThan(1000));
      expect(lngDiff, greaterThan(100));
      expect(lngDiff, lessThan(1500));
    });

    test('上海/深圳偏移同样在合理量级', () {
      // GCJ-02 偏移方向因地而异，只校验量级（经度恒向东、数百米级）
      final shanghai = wgs84ToGcj02(31.2304, 121.4737);
      expect(
        (shanghai.longitude - 121.4737).abs() * 95000,
        inExclusiveRange(100, 1500),
      );
      final shenzhen = wgs84ToGcj02(22.5431, 114.0579);
      expect(
        (shenzhen.longitude - 114.0579).abs() * 102000,
        inExclusiveRange(100, 1500),
      );
      expect(
        (shenzhen.latitude - 22.5431).abs() * 111000,
        inExclusiveRange(100, 1000),
      );
    });

    test('同一点转换结果确定', () {
      final a = wgs84ToGcj02(22.5431, 114.0579);
      final b = wgs84ToGcj02(22.5431, 114.0579);
      expect(a.latitude, b.latitude);
      expect(a.longitude, b.longitude);
    });
  });
}
