import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import 'package:ev_tool_app/core/domain/stations.dart' show GeocoderRegion;
import 'package:ev_tool_app/core/utils/logger.dart';

/// CLPlacemark → [GeocoderRegion] 纯映射（可测；不触碰插件）。
///
/// province=州/省，city=市（locality 缺失回退 subAdministrativeArea，
/// 再缺失回退 province，对齐原腾讯口径的"直辖市城市为空补省"）；
/// poiTitle=CLPlacemark.name（POI/街道名），address=street/thoroughfare。
GeocoderRegion? placemarkToRegion(Placemark? placemark) {
  if (placemark == null) {
    return null;
  }
  final province = _clean(placemark.administrativeArea);
  final locality = _clean(placemark.locality);
  final subAdmin = _clean(placemark.subAdministrativeArea);
  final city = locality.isNotEmpty
      ? locality
      : (subAdmin.isNotEmpty ? subAdmin : province);
  final poiTitle = _clean(placemark.name);
  final address = _firstNonEmpty([placemark.street, placemark.thoroughfare]);
  if (province.isEmpty && city.isEmpty && poiTitle.isEmpty && address.isEmpty) {
    return null; // 空白 placemark 视为解析失败
  }
  return GeocoderRegion(
    province: province,
    city: city,
    address: address,
    poiTitle: poiTitle,
  );
}

String _clean(String? value) => value?.trim() ?? '';

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final cleaned = _clean(value);
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
  }
  return '';
}

/// 逆地理仓储：CLGeocoder（设备端 Apple 服务，英文结果）。
///
/// 失败（无网/限流/无结果）一律返回 null，调用方静默降级，不抛异常。
class GeocodingRepository {
  GeocodingRepository() : _geocoding = Geocoding(locale: const Locale('en'));

  final Geocoding _geocoding;

  Future<GeocoderRegion?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      return placemarkToRegion(placemarks.isEmpty ? null : placemarks.first);
    } on Exception catch (error) {
      appLogger.w('Reverse geocode failed', error: error);
      return null;
    }
  }
}

final geocodingRepositoryProvider = Provider<GeocodingRepository>(
  (ref) => GeocodingRepository(),
);
