import 'package:ev_tool_app/core/domain/data/city_coords.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cityCoords 静态数据完整性', () {
    test('覆盖 34 个省级行政区且每省城市列表非空', () {
      // Act & Assert
      expect(cityCoords.length, 34);
      for (final province in cityCoords.keys) {
        expect(province, isNotEmpty);
        expect(cityCoords[province], isNotEmpty);
      }
    });

    test('所有城市名非空且坐标在合理范围内（lat 3-54，lng 73-136）', () {
      // Act & Assert
      for (final entry in cityCoords.entries) {
        for (final city in entry.value) {
          expect(city.name, isNotEmpty, reason: '${entry.key} 存在空城市名');
          expect(
            city.lat,
            greaterThanOrEqualTo(3),
            reason: '${entry.key}/${city.name} 纬度越界: ${city.lat}',
          );
          expect(
            city.lat,
            lessThanOrEqualTo(54),
            reason: '${entry.key}/${city.name} 纬度越界: ${city.lat}',
          );
          expect(
            city.lng,
            greaterThanOrEqualTo(73),
            reason: '${entry.key}/${city.name} 经度越界: ${city.lng}',
          );
          expect(
            city.lng,
            lessThanOrEqualTo(136),
            reason: '${entry.key}/${city.name} 经度越界: ${city.lng}',
          );
        }
      }
    });

    test('总城市数与源表一致（351 个）', () {
      // Act
      final count = cityCoords.values
          .map((cities) => cities.length)
          .reduce((a, b) => a + b);
      // Assert
      expect(count, 351);
    });

    test('抽样城市坐标与源表一致', () {
      // Act & Assert
      expect(cityCoords['广东省']!.first.name, '广州');
      expect(cityCoords['广东省']!.first.lat, 23.129);
      expect(cityCoords['广东省']!.first.lng, 113.264);
      expect(cityCoords['北京市']!.first.lat, 39.904);
      expect(cityCoords['北京市']!.first.lng, 116.407);
      expect(cityCoords['新疆维吾尔自治区']!.first.name, '乌鲁木齐');
      expect(cityCoords['新疆维吾尔自治区']!.first.lng, 87.617);
    });

    test('四直辖市与港澳台均有条目', () {
      // Act & Assert
      expect(cityCoords.containsKey('北京市'), isTrue);
      expect(cityCoords.containsKey('天津市'), isTrue);
      expect(cityCoords.containsKey('上海市'), isTrue);
      expect(cityCoords.containsKey('重庆市'), isTrue);
      expect(cityCoords.containsKey('香港特别行政区'), isTrue);
      expect(cityCoords.containsKey('澳门特别行政区'), isTrue);
      expect(cityCoords.containsKey('台湾省'), isTrue);
    });
  });
}
