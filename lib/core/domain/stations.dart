/// Pure functions for nearby charging stations (no Flutter dependency,
/// testable).
///
/// Ported from the EVTool mini-program src/lib/stations.js.
/// Data flow: Tencent LBS place/search POI → [normalizeStation] → Station
/// → [sortStationsByDistance] → [buildMapMarkers] (map markers).
library;

import 'dart:math' as math;

/// Mean earth radius (meters).
const double earthRadiusMeters = 6371000;

/// Distance formatting: below 1km show meters.
const int _kmThreshold = 1000;

/// Cache TTL: charging stations change slowly, reuse the same-position
/// result for 30 minutes.
const int cacheTtlMs = 30 * 60 * 1000;

/// Coordinate cell precision: 2 decimals ≈ 1.1km, matching the 1km
/// search radius.
const int _cacheCellDecimals = 2;

/// Brand-selected callout background color (aligned with the original
/// project constants.js COLORS.PRIMARY_CONTAINER).
const String _primaryContainerColor = '#059669';

/// Callout text/border white (aligned with constants.js COLORS.WHITE).
const String _whiteColor = '#FFFFFF';

/// A latitude/longitude coordinate point.
class LatLng {
  const LatLng({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// A normalized charging station.
class Station {
  const Station({
    required this.id,
    required this.name,
    required this.address,
    required this.tel,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.category,
  });

  final String id;
  final String name;
  final String address;
  final String tel;
  final double latitude;
  final double longitude;

  /// Distance from the origin (meters); null when uncomputable (sorted last).
  final double? distance;
  final String category;

  /// Returns a new instance with only distance replaced (immutable).
  Station copyWith({double? distance}) => Station(
    id: id,
    name: name,
    address: address,
    tel: tel,
    latitude: latitude,
    longitude: longitude,
    distance: distance ?? this.distance,
    category: category,
  );
}

/// A map marker callout (brand-styled always-on bubble for the selected
/// station).
class MarkerCallout {
  const MarkerCallout({
    required this.content,
    required this.display,
    required this.bgColor,
    required this.color,
    required this.fontSize,
    required this.borderRadius,
    required this.padding,
    required this.borderWidth,
    required this.borderColor,
    required this.textAlign,
  });

  final String content;
  final String display;
  final String bgColor;
  final String color;
  final int fontSize;
  final int borderRadius;
  final int padding;
  final int borderWidth;
  final String borderColor;
  final String textAlign;
}

/// A map marker (the array index is the marker id; the page looks the
/// station back up by index).
class StationMarker {
  const StationMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.iconPath,
    required this.width,
    required this.height,
    required this.anchorX,
    required this.anchorY,
    this.callout,
  });

  final int id;
  final double latitude;
  final double longitude;
  final String iconPath;
  final int width;
  final int height;

  /// Circular badge anchor centered so the pin sits exactly on the
  /// coordinate.
  final double anchorX;
  final double anchorY;
  final MarkerCallout? callout;
}

/// A coordinate cell (same cell means same position; cache hit condition).
class CacheCell {
  const CacheCell({required this.latCell, required this.lngCell});

  final double latCell;
  final double lngCell;

  @override
  bool operator ==(Object other) =>
      other is CacheCell &&
      other.latCell == latCell &&
      other.lngCell == lngCell;

  @override
  int get hashCode => Object.hash(latCell, lngCell);
}

/// Nearby-station cache (read from storage; may be empty/dirty).
class StationCache {
  const StationCache({
    required this.latCell,
    required this.lngCell,
    required this.stations,
    required this.savedAt,
  });

  final double latCell;
  final double lngCell;
  final List<Station> stations;
  final int savedAt;
}

/// Administrative region info (for charging location auto-fill).
class GeocoderRegion {
  const GeocoderRegion({
    required this.province,
    required this.city,
    required this.address,
    this.poiTitle = '',
  });

  final String province;
  final String city;
  final String address;

  /// Nearest POI title (returned when the geocoder call carries get_poi=1,
  /// sorted by distance ascending); empty string means the response had no
  /// POI and the caller should fall back to [address].
  final String poiTitle;
}

/// JS `Number()` semantics: null → NaN (callers handle the case where
/// Number(null) === 0), string numerics are tolerated, invalid → NaN.
double _toNumber(dynamic value) {
  if (value == null) {
    return double.nan;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is bool) {
    return value ? 1 : 0;
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 0; // JS Number("") === 0
    }
    return double.tryParse(trimmed) ?? double.nan;
  }
  return double.nan;
}

/// Spherical distance (Haversine formula), in meters.
/// Both sides use gcj02; error is negligible for display and sorting.
double haversineDistance(double lat1, double lng1, double lat2, double lng2) {
  final radLat1 = (lat1 * math.pi) / 180;
  final radLat2 = (lat2 * math.pi) / 180;
  final dLat = radLat1 - radLat2;
  final dLng = ((lng1 - lng2) * math.pi) / 180;
  final sinLat = math.sin(dLat / 2);
  final sinLng = math.sin(dLng / 2);
  final h =
      sinLat * sinLat + math.cos(radLat1) * math.cos(radLat2) * sinLng * sinLng;
  return 2 * earthRadiusMeters * math.asin(math.min(1, math.sqrt(h)));
}

/// Distance formatting: 850 → "850m", 1234 → "1.2km", invalid → "".
String formatDistance(num? meters) {
  final value = _toNumber(meters);
  if (value.isNaN || value < 0) {
    return '';
  }
  if (value < _kmThreshold) {
    return '${value.round()}m';
  }
  return '${(value / _kmThreshold).toStringAsFixed(1)}km';
}

/// Tencent LBS POI → [Station].
/// [poi] is a point returned by place/search
/// (id/title/address/tel/location/_distance/category);
/// [origin] is the distance origin (recomputed as a fallback when
/// `_distance` is missing). Returns null for invalid points.
Station? normalizeStation(Map<String, dynamic>? poi, LatLng origin) {
  final location = poi?['location'];
  if (poi == null || location is! Map) {
    return null;
  }
  final latitude = _toNumber(location['lat']);
  final longitude = _toNumber(location['lng']);
  if (latitude.isNaN || longitude.isNaN) {
    return null;
  }
  final rawDistance = _toNumber(poi['_distance']);
  final distance = rawDistance.isFinite
      ? rawDistance
      : haversineDistance(
          origin.latitude,
          origin.longitude,
          latitude,
          longitude,
        );
  return Station(
    id: '${poi['id']}',
    name: _orDefault(poi['title'], 'Unnamed station'),
    address: _orDefault(poi['address'], ''),
    tel: _orDefault(poi['tel'], ''),
    latitude: latitude,
    longitude: longitude,
    distance: distance,
    category: _orDefault(poi['category'], ''),
  );
}

/// JS `poi.title || fallback` semantics: empty string/null both take the
/// fallback.
String _orDefault(dynamic value, String fallback) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  if (value != null && value is! String) {
    return value.toString();
  }
  return fallback;
}

/// Sort by distance ascending (null distances last); returns a new array
/// without modifying the original. Matches JS `Array#sort`: equal elements
/// keep their relative order (stable sort).
List<Station> sortStationsByDistance(List<Station>? stations) {
  if (stations == null) {
    return [];
  }
  // Index tiebreaker for stability (Dart List.sort is not stable).
  final indices = List<int>.generate(stations.length, (i) => i);
  indices.sort((a, b) {
    final aDistance = stations[a].distance;
    final bDistance = stations[b].distance;
    int order;
    if (aDistance == null && bDistance == null) {
      order = 0;
    } else if (aDistance == null) {
      order = 1;
    } else if (bDistance == null) {
      order = -1;
    } else {
      order = aDistance.compareTo(bDistance);
    }
    return order != 0 ? order : a.compareTo(b);
  });
  return [for (final index in indices) stations[index]];
}

/// Build map markers.
///
/// The map component requires numeric marker ids while LBS POI ids are
/// strings, so the array index is the marker id; the page looks the station
/// up by index on tap. [calloutBgColor] is the selected-station callout
/// background (brand color, passed by the caller per the current theme;
/// the default brand green keeps backward compatibility).
List<StationMarker> buildMapMarkers(
  List<Station>? stations, {
  String? selectedId,
  String iconPath = '',
  String activeIconPath = '',
  String calloutBgColor = _primaryContainerColor,
}) {
  if (stations == null) {
    return [];
  }
  return List.generate(stations.length, (index) {
    final station = stations[index];
    final isSelected = station.id == selectedId;
    return StationMarker(
      id: index,
      latitude: station.latitude,
      longitude: station.longitude,
      iconPath: isSelected ? activeIconPath : iconPath,
      width: isSelected ? 44 : 32,
      height: isSelected ? 44 : 32,
      anchorX: 0.5,
      anchorY: 0.5,
      callout: isSelected
          ? MarkerCallout(
              content: station.name,
              display: 'ALWAYS',
              bgColor: calloutBgColor,
              color: _whiteColor,
              fontSize: 12,
              borderRadius: 16,
              padding: 8,
              borderWidth: 2,
              borderColor: _whiteColor,
              textAlign: 'center',
            )
          : null,
    );
  });
}

/// Round coordinates to cell precision; same cell means same position
/// (cache hit condition).
CacheCell getCacheCell(LatLng coord) {
  final factor = math.pow(10, _cacheCellDecimals).toDouble();
  return CacheCell(
    latCell: (coord.latitude * factor).round() / factor,
    lngCell: (coord.longitude * factor).round() / factor,
  );
}

/// Whether the cache is directly usable: cell matches and within TTL.
bool isCacheFresh(StationCache? cache, CacheCell cell, int now) {
  if (cache == null) {
    return false;
  }
  final isSameCell =
      cache.latCell == cell.latCell && cache.lngCell == cell.lngCell;
  final isWithinTtl = now - cache.savedAt < cacheTtlMs && now >= cache.savedAt;
  return isSameCell && isWithinTtl;
}

/// Recompute each station's distance for a new origin (on cache hits the
/// current position differs from the cache origin within the cell),
/// immutable.
List<Station> rebaseStationDistances(List<Station>? stations, LatLng origin) {
  if (stations == null) {
    return [];
  }
  return [
    for (final station in stations)
      station.copyWith(
        distance: haversineDistance(
          origin.latitude,
          origin.longitude,
          station.latitude,
          station.longitude,
        ),
      ),
  ];
}

/// Tencent LBS geocoder/v1 response → [GeocoderRegion] (for charging
/// location auto-fill).
///
/// [body] is the geocoder response (status 0 means success);
/// province/city come from result.address_component; address takes the
/// recommended address (formatted_addresses.recommend) with result.address
/// as fallback, used as the default location name; non-zero status /
/// missing structure / empty municipality city filled with province all
/// invalid → null.
GeocoderRegion? normalizeGeocoderResult(Map<String, dynamic>? body) {
  if (body == null) {
    return null;
  }
  final result = body['result'];
  final component = result is Map ? result['address_component'] : null;
  final status = body['status'];
  // JS semantics: body.status !== 0 (string "0", undefined are all non-zero).
  if (status is! num || status != 0) {
    return null;
  }
  if (component is! Map || !_isTruthy(component['province'])) {
    return null;
  }
  final province = '${component['province']}';
  // Municipality geocoder city may be an empty string; fill with province.
  final city = _isTruthy(component['city']) ? '${component['city']}' : province;
  final formatted = result is Map ? result['formatted_addresses'] : null;
  final recommend = formatted is Map ? formatted['recommend'] : null;
  final rawAddress = result is Map ? result['address'] : null;
  final address = _isTruthy(recommend)
      ? '$recommend'
      : _isTruthy(rawAddress)
      ? '$rawAddress'
      : '';
  return GeocoderRegion(province: province, city: city, address: address);
}

/// geocoder/v1 (with get_poi=1) response → nearest POI title.
///
/// Tencent returns `result.pois` sorted by distance ascending; take the
/// first valid `title`; missing structure / empty / invalid input → null
/// (pure functions never throw).
String? nearestPoiTitle(Map<String, dynamic>? body) {
  if (body == null) {
    return null;
  }
  final result = body['result'];
  if (result is! Map) {
    return null;
  }
  final pois = result['pois'];
  if (pois is! List) {
    return null;
  }
  for (final poi in pois) {
    if (poi is! Map) continue;
    final title = poi['title'];
    if (_isTruthy(title)) {
      return '$title';
    }
  }
  return null;
}

/// JS truthiness: null / empty string are falsy.
bool _isTruthy(dynamic value) {
  if (value == null) {
    return false;
  }
  if (value is String) {
    return value.isNotEmpty;
  }
  return true;
}
