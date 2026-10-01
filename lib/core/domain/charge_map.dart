import 'dart:math' as math;

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/data/city_coords.dart';
import 'package:ev_tool_app/core/domain/stations.dart';

/// 充电点位地图纯函数（移植小程序 src/lib/chargeMap.js）。
///
/// 数据流：充电记录 → [groupRecordsByLocation]（点位聚合）→
/// [buildLocationMarkers]（地图标注）→ [calcCityTop]/[calcLocationStats]。
/// 坐标系：GCJ-02。

/// 城市名匹配时需要剥离的行政后缀（region 选择器返回"广州市"等全称）。
const List<String> _cityNameSuffixes = ['自治州', '地区', '盟', '市'];

/// 点位聚合时兜底展示名（只有城市无具体地点名）。
const String cityPointName = '城市充电点';

/// 同坐标散开半径（度）：约 1.1km。
const double scatterRadiusDeg = 0.01;

/// fit-all 缩放上下限。
const int fitScaleMin = 4;
const int fitScaleMax = 14;

const double _mapViewWidthPx = 375;
const double _mapViewHeightPx = 350;
const double _fitPaddingRatio = 1.2;

/// 点位聚合结果。
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

/// 地图标注（数据字段；具体渲染由地图封装 widget 决定）。
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

/// fit-all 视口。
class MapViewport {
  const MapViewport({
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  final double latitude;
  final double longitude;

  /// Web 墨卡托 zoom（Apple MapKit 的 camera zoom 语义近似）。
  final double zoom;
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

/// 省市 → 预设城市条目（归一到预设简称，统一存储口径）。
///
/// 未收录返回 null（调用方回退原值）。
String? matchCity(String province, String city) {
  final cities = cityCoords[province];
  if (cities == null) return null;
  for (final entry in cities) {
    if (_matchCityName(entry.name, city)) return entry.name;
  }
  return null;
}

/// 省市 → 城市中心点坐标；未收录返回 null。
CityCoord? getCityCoord(String province, String city) {
  final cities = cityCoords[province];
  if (cities == null) return null;
  for (final entry in cities) {
    if (_matchCityName(entry.name, city)) return entry;
  }
  return null;
}

/// 坐标 → 最近城市（地图选点后补 province/city 用）。
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

/// 坐标 → 最近城市（含该城市中心坐标）；非法坐标返回 null。
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

/// 按地点聚合记录（地图页散点数据源）。
///
/// 聚合键：城市 + 地点名（无地点名按"城市充电点"），同键点位取首条记录坐标，
/// 按次数降序。
List<LocationGroup> groupRecordsByLocation(List<ChargeRecord> records) {
  final groups = <String, _MutableGroup>{};
  for (final record in records) {
    if (!_hasLocation(record)) continue;
    final city = (record.city?.isNotEmpty ?? false) ? record.city! : '未知城市';
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
  // JS: Array#sort 稳定；Dart sort 不稳定，加 key 次序稳定化。
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

/// 同坐标点位散开：按经纬度分桶，桶内多于 1 个时圆形排布加偏移。
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

/// 构建点位标注：下标即 id；家充为主 → 绿点，否则橙点；选中放大带气泡。
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
            ? '${groups[i].locationName} · ${groups[i].count}次'
            : null,
      ),
  ];
}

/// 高频充电城市 TOP N（按有城市名的记录计数）。
List<({String city, int count})> calcCityTop(
  List<ChargeRecord> records, [
  int topN = 3,
]) {
  final counts = <String, int>{};
  for (final record in records) {
    final city = record.city;
    if (city == null || city.isEmpty) continue;
    counts[city] = (counts[city] ?? 0) + 1;
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

/// 点位统计面板数据（按有地点的记录计；比例 0-100 整数）。
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

/// 地图初始视野：包围盒自适应。
///
/// 无点位 → fallback + 全国视野(4)；单点位 → 该点 + 城市视野(11)；
/// 多点位 → 包围盒中心 + Web 墨卡托 zoom 换算（外扩 1.2 留白，
/// 向下取整，clamp [4, 14]）。
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
