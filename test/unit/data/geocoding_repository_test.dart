import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';

import 'package:ev_tool_app/features/records/data/geocoding_repository.dart';

void main() {
  group('placemarkToRegion', () {
    test('完整 placemark 映射省/市/POI/街道', () {
      final region = placemarkToRegion(
        const Placemark(
          name: 'Apple Park',
          street: 'One Apple Park Way',
          administrativeArea: 'California',
          subAdministrativeArea: 'Santa Clara County',
          locality: 'Cupertino',
          thoroughfare: 'Apple Park Way',
        ),
      );

      expect(region, isNotNull);
      expect(region!.province, 'California');
      expect(region.city, 'Cupertino');
      expect(region.poiTitle, 'Apple Park');
      expect(region.address, 'One Apple Park Way');
    });

    test('locality 为空时回退 subAdministrativeArea', () {
      final region = placemarkToRegion(
        const Placemark(
          name: 'Downtown',
          administrativeArea: 'California',
          subAdministrativeArea: 'Santa Clara County',
        ),
      );

      expect(region!.city, 'Santa Clara County');
    });

    test('city 全空时回退 province（对齐直辖市口径）', () {
      final region = placemarkToRegion(
        const Placemark(name: 'Somewhere', administrativeArea: 'Singapore'),
      );

      expect(region!.city, 'Singapore');
    });

    test('street 为空时 address 回退 thoroughfare', () {
      final region = placemarkToRegion(
        const Placemark(
          name: 'Spot',
          administrativeArea: 'California',
          locality: 'Cupertino',
          thoroughfare: 'Stevens Creek Blvd',
        ),
      );

      expect(region!.address, 'Stevens Creek Blvd');
    });

    test('全空 placemark 视为解析失败返回 null', () {
      const empty = Placemark();

      expect(placemarkToRegion(empty), isNull);
    });

    test('null 入参返回 null', () {
      expect(placemarkToRegion(null), isNull);
    });
  });
}
