/// WGS-84 → GCJ-02 坐标转换（国测局加密坐标）。
///
/// iOS CoreLocation 返回 WGS-84，而本项目地图（Apple MapKit 中国区）
/// 与腾讯 LBS 逆地理均使用 GCJ-02；不转换会有 ~100-700m 系统性偏差。
/// 采用业界通用的 transformLat/Lng 近似算法（误差 < 1-2m）。
library;

import 'dart:math' show cos, pi, sin, sqrt;

const double _a = 6378245;
const double _ee = 0.00669342162296594323;

class Gcj02Point {
  const Gcj02Point({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

bool _outOfChina(double lat, double lng) {
  return lng < 72.004 || lng > 137.8347 || lat < 0.8293 || lat > 55.8271;
}

double _transformLat(double x, double y) {
  var ret =
      -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(x);
  ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
  ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
  ret += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0;
  return ret;
}

double _transformLng(double x, double y) {
  var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(x);
  ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
  ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
  ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
  return ret;
}

/// WGS-84 坐标转 GCJ-02；国界外原样返回。
Gcj02Point wgs84ToGcj02(double wgsLat, double wgsLng) {
  if (_outOfChina(wgsLat, wgsLng)) {
    return Gcj02Point(latitude: wgsLat, longitude: wgsLng);
  }
  var dLat = _transformLat(wgsLng - 105.0, wgsLat - 35.0);
  var dLng = _transformLng(wgsLng - 105.0, wgsLat - 35.0);
  final radLat = wgsLat / 180.0 * pi;
  var magic = sin(radLat);
  magic = 1 - _ee * magic * magic;
  final sqrtMagic = sqrt(magic);
  dLat = (dLat * 180.0) / ((_a * (1 - _ee)) / (magic * sqrtMagic) * pi);
  dLng = (dLng * 180.0) / (_a / sqrtMagic * cos(radLat) * pi);
  return Gcj02Point(latitude: wgsLat + dLat, longitude: wgsLng + dLng);
}
