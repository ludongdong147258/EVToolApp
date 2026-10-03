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

    test('所有城市英文名/中文匹配键非空且坐标在合理范围内（lat 3-54，lng 73-136）', () {
      // Act & Assert
      for (final entry in cityCoords.entries) {
        for (final city in entry.value) {
          expect(city.name, isNotEmpty, reason: '${entry.key} 存在空城市名');
          expect(
            city.zh,
            isNotEmpty,
            reason: '${entry.key}/${city.name} 缺少中文匹配键',
          );
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
      expect(cityCoords['Guangdong']!.first.name, 'Guangzhou');
      expect(cityCoords['Guangdong']!.first.zh, '广州');
      expect(cityCoords['Guangdong']!.first.lat, 23.129);
      expect(cityCoords['Guangdong']!.first.lng, 113.264);
      expect(cityCoords['Beijing']!.first.lat, 39.904);
      expect(cityCoords['Beijing']!.first.lng, 116.407);
      expect(cityCoords['Xinjiang']!.first.name, 'Urumqi');
      expect(cityCoords['Xinjiang']!.first.zh, '乌鲁木齐');
      expect(cityCoords['Xinjiang']!.first.lng, 87.617);
    });

    test('四直辖市与港澳台均有条目', () {
      // Act & Assert
      expect(cityCoords.containsKey('Beijing'), isTrue);
      expect(cityCoords.containsKey('Tianjin'), isTrue);
      expect(cityCoords.containsKey('Shanghai'), isTrue);
      expect(cityCoords.containsKey('Chongqing'), isTrue);
      expect(cityCoords.containsKey('Hong Kong'), isTrue);
      expect(cityCoords.containsKey('Macau'), isTrue);
      expect(cityCoords.containsKey('Taiwan'), isTrue);
    });
  });

  group('provinceZhKeys 中文省份匹配键', () {
    test('每个中文省份名都映射到存在的英文省份 key', () {
      // Act & Assert
      expect(provinceZhKeys.length, cityCoords.length);
      for (final entry in provinceZhKeys.entries) {
        expect(
          cityCoords.containsKey(entry.value),
          isTrue,
          reason: '${entry.key} → ${entry.value} 不在 cityCoords 中',
        );
      }
    });

    test('腾讯逆地理返回的省份全称均可命中', () {
      // Act & Assert
      expect(provinceZhKeys['广东省'], 'Guangdong');
      expect(provinceZhKeys['浙江省'], 'Zhejiang');
      expect(provinceZhKeys['内蒙古自治区'], 'Inner Mongolia');
      expect(provinceZhKeys['广西壮族自治区'], 'Guangxi');
      expect(provinceZhKeys['新疆维吾尔自治区'], 'Xinjiang');
      expect(provinceZhKeys['香港特别行政区'], 'Hong Kong');
      expect(provinceZhKeys['陕西省'], 'Shaanxi');
      expect(provinceZhKeys['山西省'], 'Shanxi');
    });
  });
}
