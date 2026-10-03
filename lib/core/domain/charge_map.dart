import 'dart:math' as math;

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/data/city_coords.dart';
import 'package:ev_tool_app/core/domain/stations.dart';

/// Pure functions for the charging locations map (ported from the
/// mini-program src/lib/chargeMap.js).
///
/// Data flow: charging records → [groupRecordsByLocation] (location
/// aggregation) → [buildLocationMarkers] (map markers) →
/// [calcCityTop]/[calcLocationStats]. Coordinate system: GCJ-02.

/// Administrative suffixes to strip when matching city names (the region
/// picker / Tencent geocoder return full Chinese administrative names).
const List<String> _cityNameSuffixes = ['自治州', '地区', '盟', '市'];

/// Fallback display name for aggregation when only the city is known
/// (no concrete location name).
const String cityPointName = 'City charging point';

/// Scatter radius for coincident points (degrees): about 1.1km.
const double scatterRadiusDeg = 0.01;

/// fit-all zoom bounds.
const int fitScaleMin = 4;
const int fitScaleMax = 14;

const double _mapViewWidthPx = 375;
const double _mapViewHeightPx = 350;
const double _fitPaddingRatio = 1.2;

/// Result of location aggregation.
class LocationGroup {
  const LocationGroup({
    required this.key,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.city,
    required this.province,
    required this.count,
    required this.homeCount,
    required this.fastCount,
    required this.totalCost,
    required this.totalEnergy,
    required this.records,
  });

  final String key;
  final double latitude;
  final double longitude;
  final String locationName;
  final String city;
  final String? province;
  final int count;
  final int homeCount;
  final int fastCount;
  final double totalCost;
  final double totalEnergy;
  final List<ChargeRecord> records;
}

/// A map marker (data fields only; rendering is up to the map wrapper widget).
class LocationMarker {
  const LocationMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.isHome,
    required this.isSelected,
    required this.calloutText,
  });

  final int id;
  final double latitude;
  final double longitude;
  final bool isHome;
  final bool isSelected;
  final String? calloutText;
}

/// fit-all viewport.
class MapViewport {
  const MapViewport({
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  final double latitude;
  final double longitude;

  /// Web Mercator zoom (approximately Apple MapKit camera zoom semantics).
  final double zoom;
}

/// Province input may be an English map key (e.g. "Guangdong") or the
/// Chinese name returned by Tencent reverse geocoding — resolve to the city
/// list either way.
List<CityCoord>? _provinceCities(String province) {
  final direct = cityCoords[province];
  if (direct != null) return direct;
  final englishKey = provinceZhKeys[province];
  return englishKey == null ? null : cityCoords[englishKey];
}

bool _matchCityName(String presetName, String pickerName) {
  if (presetName == pickerName) return true;
  var stripped = pickerName;
  for (final suffix in _cityNameSuffixes) {
    if (stripped.endsWith(suffix)) {
      stripped = stripped.substring(0, stripped.length - suffix.length);
    }
  }
  return presetName == stripped || pickerName.contains(presetName);
}

/// Province/city → preset city entry name (normalized to the preset short
/// name for a unified storage vocabulary). Matching uses the Chinese [CityCoord.zh]
/// key because picker/geocoder inputs are Chinese; the returned name is English.
///
/// Returns null when not found (caller keeps the original value).
String? matchCity(String province, String city) {
  final cities = _provinceCities(province);
  if (cities == null) return null;
  for (final entry in cities) {
    if (_matchesCity(entry, city)) return entry.name;
  }
  return null;
}

/// Province/city → city center coordinates; null when not found.
CityCoord? getCityCoord(String province, String city) {
  final cities = _provinceCities(province);
  if (cities == null) return null;
  for (final entry in cities) {
    if (_matchesCity(entry, city)) return entry;
  }
  return null;
}

/// 城市匹配：中文 zh 键（含行政后缀剥离）或英文 name 精确相等。
/// 英文名也必须认——matchCity/findNearestCity 返回并落盘的就是英文名，
/// 存量值回读（幂等）不能解析失败。
bool _matchesCity(CityCoord entry, String city) {
  return _matchCityName(entry.zh, city) || entry.name == city;
}

/// Coordinates → nearest city (used to fill province/city after map picking).
_CityHit? _findNearestCity(double latitude, double longitude) {
  _CityHit? best;
  var bestDistance = double.infinity;
  for (final province in cityCoords.keys) {
    for (final entry in cityCoords[province]!) {
      final distance = haversineDistance(
        latitude,
        longitude,
        entry.lat,
        entry.lng,
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        best = _CityHit(province: province, entry: entry);
      }
    }
  }
  return best;
}

/// Coordinates → nearest city (including its center coordinates);
/// null for invalid coordinates.
NearestCity? findNearestCity(num? latitude, num? longitude) {
  final lat = latitude?.toDouble();
  final lng = longitude?.toDouble();
  if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) {
    return null;
  }
  final hit = _findNearestCity(lat, lng);
  if (hit == null) return null;
  return NearestCity(
    province: hit.province,
    city: hit.entry.name,
    latitude: hit.entry.lat,
    longitude: hit.entry.lng,
  );
}

class NearestCity {
  const NearestCity({
    required this.province,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  final String province;
  final String city;
  final double latitude;
  final double longitude;
}

class _CityHit {
  const _CityHit({required this.province, required this.entry});

  final String province;
  final CityCoord entry;
}

bool _hasLocation(ChargeRecord record) =>
    record.latitude != null &&
    record.longitude != null &&
    record.latitude!.isFinite &&
    record.longitude!.isFinite;

/// 城市显示/聚合键归一：旧记录可能存中文（腾讯逆地理），新记录存英文，
/// 同城统一解析为英文名；解析不到原样保留。
String _normalizeCityKey(ChargeRecord record) {
  final city = record.city;
  if (city == null || city.isEmpty) return city ?? '';
  final province = record.province;
  if (province == null || province.isEmpty) return city;
  return matchCity(province, city) ?? city;
}

/// Aggregate records by location (data source for the map page scatter).
///
/// Aggregation key: city + location name (records without a location name
/// fall back to [cityPointName]); coincident keys take the first record's
/// coordinates; sorted by count descending.
List<LocationGroup> groupRecordsByLocation(List<ChargeRecord> records) {
  final groups = <String, _MutableGroup>{};
  for (final record in records) {
    if (!_hasLocation(record)) continue;
    final city = (record.city?.isNotEmpty ?? false)
        ? _normalizeCityKey(record)
        : 'Unknown city';
    final locationName = (record.locationName?.isNotEmpty ?? false)
        ? record.locationName!
        : cityPointName;
    final key = '$city|$locationName';
    final group = groups.putIfAbsent(
      key,
      () => _MutableGroup(
        key: key,
        latitude: record.latitude!,
        longitude: record.longitude!,
        locationName: locationName,
        city: city,
        province: (record.province?.isNotEmpty ?? false)
            ? record.province
            : null,
      ),
    );
    group.count += 1;
    if (record.type == 'home') {
      group.homeCount += 1;
    } else if (record.type == 'fast') {
      group.fastCount += 1;
    }
    group.totalCost += record.cost;
    group.totalEnergy += record.energy;
    group.records.add(record);
  }
  final result = groups.values.map((g) => g.freeze()).toList();
  // JS: Array#sort is stable; Dart sort is not, so add a key tiebreaker.
  result.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    return a.key.compareTo(b.key);
  });
  return result;
}

class _MutableGroup {
  _MutableGroup({
    required this.key,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.city,
    required this.province,
  });

  final String key;
  final double latitude;
  final double longitude;
  final String locationName;
  final String city;
  final String? province;
  int count = 0;
  int homeCount = 0;
  int fastCount = 0;
  double totalCost = 0;
  double totalEnergy = 0;
  final List<ChargeRecord> records = [];

  LocationGroup freeze() => LocationGroup(
    key: key,
    latitude: latitude,
    longitude: longitude,
    locationName: locationName,
    city: city,
    province: province,
    count: count,
    homeCount: homeCount,
    fastCount: fastCount,
    totalCost: totalCost,
    totalEnergy: totalEnergy,
    records: List.unmodifiable(records),
  );
}

/// Scatter coincident points: bucket by lat/lng, and when a bucket has more
/// than one member, arrange them in a circle with an offset.
List<({double latitude, double longitude})> _scatterCoincident(
  List<LocationGroup> groups,
) {
  final buckets = <String, List<int>>{};
  for (var i = 0; i < groups.length; i++) {
    final key = '${groups[i].latitude},${groups[i].longitude}';
    buckets.putIfAbsent(key, () => []).add(i);
  }
  final offsets = List<(double, double)>.generate(groups.length, (_) => (0, 0));
  for (final members in buckets.values) {
    if (members.length == 1) continue;
    for (var slot = 0; slot < members.length; slot++) {
      final angle = (2 * math.pi * slot) / members.length;
      offsets[members[slot]] = (
        scatterRadiusDeg * math.sin(angle),
        scatterRadiusDeg * math.cos(angle),
      );
    }
  }
  return [
    for (var i = 0; i < groups.length; i++)
      (
        latitude: groups[i].latitude + offsets[i].$1,
        longitude: groups[i].longitude + offsets[i].$2,
      ),
  ];
}

/// Build location markers: the array index is the id; home-dominant → green
/// dot, otherwise orange; the selected one is enlarged with a callout.
List<LocationMarker> buildLocationMarkers(
  List<LocationGroup> groups, {
  String? selectedKey,
}) {
  final scattered = _scatterCoincident(groups);
  return [
    for (var i = 0; i < groups.length; i++)
      LocationMarker(
        id: i,
        latitude: scattered[i].latitude,
        longitude: scattered[i].longitude,
        isHome: groups[i].homeCount > groups[i].fastCount,
        isSelected: groups[i].key == selectedKey,
        calloutText: groups[i].key == selectedKey
            ? '${groups[i].locationName} · ${groups[i].count} charge${groups[i].count == 1 ? '' : 's'}'
            : null,
      ),
  ];
}

/// Top N most-charged cities (counted over records that have a city name).
List<({String city, int count})> calcCityTop(
  List<ChargeRecord> records, [
  int topN = 3,
]) {
  final counts = <String, int>{};
  for (final record in records) {
    final city = record.city;
    if (city == null || city.isEmpty) continue;
    final key = _normalizeCityKey(record);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final entries = counts.entries
      .map((e) => (city: e.key, count: e.value))
      .toList();
  entries.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    return a.city.compareTo(b.city);
  });
  return entries.take(topN).toList();
}

/// Location stats panel data (records with a location; ratios 0-100 integers).
LocationStats calcLocationStats(List<ChargeRecord> records) {
  final located = records.where(_hasLocation).toList();
  final homeCount = located.where((r) => r.type == 'home').length;
  final fastCount = located.where((r) => r.type == 'fast').length;
  final total = located.length;
  int ratio(int part) => total > 0 ? ((part / total) * 100).round() : 0;
  return LocationStats(
    recordCount: total,
    homeCount: homeCount,
    fastCount: fastCount,
    homeRatio: ratio(homeCount),
    fastRatio: ratio(fastCount),
  );
}

class LocationStats {
  const LocationStats({
    required this.recordCount,
    required this.homeCount,
    required this.fastCount,
    required this.homeRatio,
    required this.fastRatio,
  });

  final int recordCount;
  final int homeCount;
  final int fastCount;
  final int homeRatio;
  final int fastRatio;
}

/// Initial map viewport: bounding-box fit.
///
/// No points → fallback + country-wide view (4); single point → that point +
/// city view (11); multiple points → bounding-box center + Web Mercator zoom
/// conversion (1.2 padding ratio, floor, clamp [4, 14]).
MapViewport getMapCenter(
  List<ChargeRecord> records, {
  required double fallbackLatitude,
  required double fallbackLongitude,
}) {
  final groups = groupRecordsByLocation(records);
  if (groups.isEmpty) {
    return MapViewport(
      latitude: fallbackLatitude,
      longitude: fallbackLongitude,
      zoom: 4,
    );
  }
  if (groups.length == 1) {
    return MapViewport(
      latitude: groups[0].latitude,
      longitude: groups[0].longitude,
      zoom: 11,
    );
  }

  var minLat = double.infinity, maxLat = -double.infinity;
  var minLng = double.infinity, maxLng = -double.infinity;
  for (final group in groups) {
    minLat = math.min(minLat, group.latitude);
    maxLat = math.max(maxLat, group.latitude);
    minLng = math.min(minLng, group.longitude);
    maxLng = math.max(maxLng, group.longitude);
  }
  final latSpan = math.max((maxLat - minLat) * _fitPaddingRatio, 1e-6);
  final lngSpan = math.max((maxLng - minLng) * _fitPaddingRatio, 1e-6);
  final zoomByLat =
      math.log(((_mapViewHeightPx / 256) * 180) / latSpan) / math.ln2;
  final zoomByLng =
      math.log(((_mapViewWidthPx / 256) * 360) / lngSpan) / math.ln2;
  final zoom = math.min(
    fitScaleMax.toDouble(),
    math.max(
      fitScaleMin.toDouble(),
      math.min(zoomByLat, zoomByLng).floorToDouble(),
    ),
  );
  return MapViewport(
    latitude: (minLat + maxLat) / 2,
    longitude: (minLng + maxLng) / 2,
    zoom: zoom,
  );
}
