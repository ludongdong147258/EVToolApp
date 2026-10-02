/// 附近充电桩纯函数（无 Flutter 依赖，可测）
///
/// 移植自 EVTool 小程序 src/lib/stations.js。
/// 数据流：腾讯位置服务 place/search POI → [normalizeStation] → Station
/// → [sortStationsByDistance] → [buildMapMarkers]（地图 markers）。
library;

import 'dart:math' as math;

/// 地球平均半径（米）
const double earthRadiusMeters = 6371000;

/// 距离换算：km 以下展示米
const int _kmThreshold = 1000;

/// 缓存有效期：充电桩变动慢，30 分钟内同位置直接复用
const int cacheTtlMs = 30 * 60 * 1000;

/// 坐标分格精度：2 位小数 ≈ 1.1km，与 1km 搜索半径匹配
const int _cacheCellDecimals = 2;

/// 品牌选中态气泡底色（与原项目 constants.js COLORS.PRIMARY_CONTAINER 对齐）
const String _primaryContainerColor = '#059669';

/// 气泡文字/描边白色（与原项目 constants.js COLORS.WHITE 对齐）
const String _whiteColor = '#FFFFFF';

/// 经纬度坐标点
class LatLng {
  const LatLng({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// 归一化后的充电站
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

  /// 距原点距离（米）；无法计算时为 null（排序时排尾）
  final double? distance;
  final String category;

  /// 返回仅替换 distance 的新实例（不可变）
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

/// 地图 marker 气泡（选中站点的品牌样式常显气泡）
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

/// 地图 marker（下标即 marker id，页面通过下标回查 station）
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

  /// 圆形徽章锚点居中，打点精确压在坐标上
  final double anchorX;
  final double anchorY;
  final MarkerCallout? callout;
}

/// 坐标分格（同格即视为同位置，缓存命中条件）
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

/// 附近充电站缓存（storage 读出，可能为空/脏数据）
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

/// 行政区信息（充电地点自动填充用）
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

  /// 最近 POI 标题（geocoder 携带 get_poi=1 时返回，按距离升序）；
  /// 空串表示响应未包含 POI，调用方应回退 [address]。
  final String poiTitle;
}

/// JS `Number()` 语义：null → NaN（Number(null) === 0 的场景由调用方处理），
/// 字符串数值可被容忍，非法值返回 NaN
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

/// 球面距离（Haversine 公式），单位米。
/// 坐标系两侧均为 gcj02，展示与排序用途下误差可忽略。
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

/// 距离格式化：850 → "850m"，1234 → "1.2km"，非法值 → ""
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

/// 腾讯位置服务 POI → [Station]。
/// [poi] 为 place/search 返回的点位
/// （id/title/address/tel/location/_distance/category）；
/// [origin] 为距离原点（`_distance` 缺失时兜底重算）。非法点位返回 null。
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
    name: _orDefault(poi['title'], '未命名充电站'),
    address: _orDefault(poi['address'], ''),
    tel: _orDefault(poi['tel'], ''),
    latitude: latitude,
    longitude: longitude,
    distance: distance,
    category: _orDefault(poi['category'], ''),
  );
}

/// JS `poi.title || fallback` 语义：空串/空值均取兜底值
String _orDefault(dynamic value, String fallback) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  if (value != null && value is! String) {
    return value.toString();
  }
  return fallback;
}

/// 按距离升序排列（null 距离排尾），返回新数组不修改原数组。
/// 与 JS `Array#sort` 一致：相等元素保持原有相对顺序（稳定排序）。
List<Station> sortStationsByDistance(List<Station>? stations) {
  if (stations == null) {
    return [];
  }
  // 借助下标决胜保证稳定性（Dart List.sort 不保证稳定）
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

/// 构建地图 markers。
///
/// 地图组件的 marker id 必须是数字，而 LBS 的 POI id 是字符串，
/// 故用数组下标作 marker id；页面通过下标回查 station 处理点击。
/// [calloutBgColor] 为选中站点气泡底色（品牌色，由调用方按当前主题传入，
/// 缺省品牌绿保持向后兼容）。
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

/// 坐标四舍五入到分格精度，同格即视为同位置（缓存命中条件）
CacheCell getCacheCell(LatLng coord) {
  final factor = math.pow(10, _cacheCellDecimals).toDouble();
  return CacheCell(
    latCell: (coord.latitude * factor).round() / factor,
    lngCell: (coord.longitude * factor).round() / factor,
  );
}

/// 缓存是否可直接使用：cell 匹配且未超过 TTL
bool isCacheFresh(StationCache? cache, CacheCell cell, int now) {
  if (cache == null) {
    return false;
  }
  final isSameCell =
      cache.latCell == cell.latCell && cache.lngCell == cell.lngCell;
  final isWithinTtl = now - cache.savedAt < cacheTtlMs && now >= cache.savedAt;
  return isSameCell && isWithinTtl;
}

/// 按新原点重算各站距离（缓存命中时当前定位与缓存原点存在格内偏移），不可变
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

/// 腾讯位置服务 geocoder/v1 响应 → [GeocoderRegion]（充电地点自动填充用）。
///
/// [body] 为 geocoder 接口响应（status 0 为成功）；
/// province/city 取 result.address_component；address 取推荐地址
/// （formatted_addresses.recommend）兜底 result.address，作为地点名默认值；
/// status 非 0 / 结构缺失 / 直辖市 city 为空时用 province 补位，均无效返回 null。
GeocoderRegion? normalizeGeocoderResult(Map<String, dynamic>? body) {
  if (body == null) {
    return null;
  }
  final result = body['result'];
  final component = result is Map ? result['address_component'] : null;
  final status = body['status'];
  // JS 语义：body.status !== 0（字符串 "0"、undefined 均视为非 0）
  if (status is! num || status != 0) {
    return null;
  }
  if (component is! Map || !_isTruthy(component['province'])) {
    return null;
  }
  final province = '${component['province']}';
  // 直辖市 geocoder 的 city 可能返回空串，用 province 补位
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

/// geocoder/v1（携带 get_poi=1）响应 → 最近 POI 标题。
///
/// 腾讯侧 `result.pois` 按距离升序，取首个有效 `title`；
/// 结构缺失 / 空 / 非法输入返回 null（纯函数不抛异常）。
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

/// JS truthiness：null / 空串视为假
bool _isTruthy(dynamic value) {
  if (value == null) {
    return false;
  }
  if (value is String) {
    return value.isNotEmpty;
  }
  return true;
}
