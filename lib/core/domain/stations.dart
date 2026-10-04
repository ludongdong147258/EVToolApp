/// Pure functions for nearby charging stations (no Flutter dependency,
/// testable).
///
/// Data source: OpenStreetMap Overpass API (`nwr[amenity=charging_station]`,
/// WGS-84): element → [normalizeStation] → Station →
/// [sortStationsByDistance] → page markers. (Historically ported from the
/// mini-program src/lib/stations.js with Tencent LBS; deliberately diverged
/// for the overseas build.)
library;

import 'dart:math' as math;

/// Mean earth radius (meters).
const double earthRadiusMeters = 6371000;

/// Distance formatting: below 1km show meters.
const int _kmThreshold = 1000;

/// Cache TTL: charging stations change slowly, reuse the same-position
/// result for 30 minutes.
const int cacheTtlMs = 30 * 60 * 1000;

/// Coordinate cell precision: 2 decimals ≈ 1.1km (cache granularity;
/// hits rebase distances to the current origin).
const int _cacheCellDecimals = 2;

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

/// Fast-charging threshold (kW): at or above this the category shows DC.
const double _dcPowerKwThreshold = 50;

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

  /// Nearest POI / place name (from CLPlacemark.name); empty string means
  /// the geocoder returned no name and the caller should fall back to
  /// [address].
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

/// OpenStreetMap Overpass element → [Station].
///
/// [element] is one entry of the Overpass response (`node/way/relation`
/// with `lat/lon` or `center`, `tags` carrying name/brand/sockets);
/// [origin] is the distance origin (always recomputed). Returns null for
/// invalid points; never throws.
Station? normalizeStation(Map<String, dynamic>? element, LatLng origin) {
  if (element == null) {
    return null;
  }
  final dynamic center = element['center'];
  final latitude = _toNumber(
    element['lat'] ?? (center is Map ? center['lat'] : null),
  );
  final longitude = _toNumber(
    element['lon'] ?? (center is Map ? center['lon'] : null),
  );
  if (latitude.isNaN || longitude.isNaN) {
    return null;
  }
  final dynamic rawTags = element['tags'];
  final tags = rawTags is Map ? rawTags : const <String, dynamic>{};
  final addressParts = [
    tags['addr:housenumber'],
    tags['addr:street'],
    tags['addr:city'],
  ].where(_isNonEmptyText).map((part) => '$part'.trim());
  return Station(
    id: '${element['type']}/${element['id']}',
    name: _text(
      tags['name'] ?? tags['brand'] ?? tags['operator'],
      'Unnamed station',
    ),
    address: addressParts.join(' '),
    tel: _firstPhone(tags['phone'] ?? tags['contact:phone']),
    latitude: latitude,
    longitude: longitude,
    distance: haversineDistance(
      origin.latitude,
      origin.longitude,
      latitude,
      longitude,
    ),
    category: _stationCategory(tags),
  );
}

/// Category from the strongest socket output tag (`socket:*:output`,
/// values like "50 kW" / "7"): DC at/above [_dcPowerKwThreshold], otherwise
/// AC; unknown power → empty.
String _stationCategory(Map<dynamic, dynamic> tags) {
  double? maxKw;
  for (final entry in tags.entries) {
    final key = entry.key;
    if (key is! String ||
        !key.startsWith('socket:') ||
        !key.endsWith(':output')) {
      continue;
    }
    final powerKw = _parseLeadingNumber(entry.value);
    if (powerKw != null && (maxKw == null || powerKw > maxKw)) {
      maxKw = powerKw;
    }
  }
  if (maxKw == null) {
    return '';
  }
  final rounded = maxKw.round();
  return maxKw >= _dcPowerKwThreshold ? 'DC ${rounded}kW' : 'AC ${rounded}kW';
}

/// "50 kW" → 50, "7.2 kW" → 7.2, "7" → 7; unparsable → null.
double? _parseLeadingNumber(dynamic value) {
  if (value is! String) {
    return null;
  }
  final match = RegExp(r'^\s*(\d+(?:\.\d+)?)').firstMatch(value);
  return match == null ? null : double.parse(match.group(1)!);
}

/// OSM phone tags may carry ";"-separated numbers; take the first.
String _firstPhone(dynamic value) {
  if (value is! String || value.trim().isEmpty) {
    return '';
  }
  return value.split(';').first.trim();
}

/// `value || fallback` semantics: null/blank string takes the fallback.
bool _isNonEmptyText(dynamic value) {
  return value is String && value.trim().isNotEmpty;
}

String _text(dynamic value, String fallback) {
  if (_isNonEmptyText(value)) {
    return value.trim();
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
