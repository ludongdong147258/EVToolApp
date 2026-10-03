import 'dart:ui' show ImageByteFormat, PictureRecorder;

import 'package:flutter/material.dart';

import 'package:apple_maps_flutter/apple_maps_flutter.dart';

/// Apple MapKit 唯一封装入口。
///
/// 项目规则：`apple_maps_flutter` 只允许在本文件内 import，
/// 页面层一律使用本文件定义的自有数据类型（[MapViewCameraPosition] /
/// [MapViewMarker]），日后切换高德 / 地图 SDK 时只需替换此 widget。
///
/// 注意：包含本 widget 的页面不可在 flutter test 中 pump
/// （插件通道缺失会抛 MissingPluginException）。

/// 普通徽标直径（逻辑 px，对齐小程序 marker 28px）。
const double _kBadgeSizeNormal = 28;

/// 选中徽标直径（对齐小程序选中态 36px）。
const double _kBadgeSizeSelected = 36;

/// 地图初始视野（页面层不感知 CameraPosition / LatLng 等插件类型）。
class MapViewCameraPosition {
  const MapViewCameraPosition({
    required this.latitude,
    required this.longitude,
    this.zoom = 11,
  });

  final double latitude;
  final double longitude;
  final double zoom;
}

/// 地图标注点（color 渲染为白色描边圆形徽标，[isSelected] 放大并显示
/// [calloutText] 气泡）。
class MapViewMarker {
  const MapViewMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.color,
    this.isSelected = false,
    this.calloutText,
    this.onTap,
  });

  final int id;
  final double latitude;
  final double longitude;
  final Color color;
  final bool isSelected;
  final String? calloutText;
  final VoidCallback? onTap;
}

/// Apple 地图薄封装：初始视野 + 标注集合 + 地图点击回调。
///
/// 徽标 icon 为 Canvas 自绘 PNG（异步生成、按 颜色+尺寸 缓存），
/// 生成完成前临时退化为色相 pin，避免闪烁空缺。
class AppleMapView extends StatefulWidget {
  const AppleMapView({
    super.key,
    required this.initialCameraPosition,
    this.markers = const <MapViewMarker>[],
    this.onMapTapped,
  });

  final MapViewCameraPosition initialCameraPosition;
  final List<MapViewMarker> markers;

  /// 地图点击回调（返回点击处经纬度，页面层不感知插件 LatLng 类型）。
  final void Function(double latitude, double longitude)? onMapTapped;

  @override
  State<AppleMapView> createState() => _AppleMapViewState();
}

class _AppleMapViewState extends State<AppleMapView> {
  /// 徽标位图缓存：key = '颜色值-直径'。
  final Map<String, BitmapDescriptor> _badgeCache =
      <String, BitmapDescriptor>{};

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  @override
  void didUpdateWidget(AppleMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadBadges();
  }

  /// 为当前 markers 缺失的徽标组合生成位图（已缓存的跳过）。
  Future<void> _loadBadges() async {
    final missing = <String, (Color, double)>{};
    for (final marker in widget.markers) {
      final size = marker.isSelected ? _kBadgeSizeSelected : _kBadgeSizeNormal;
      final key = '${marker.color.toARGB32()}-$size';
      if (!_badgeCache.containsKey(key)) {
        missing[key] = (marker.color, size);
      }
    }
    if (missing.isEmpty) return;

    for (final entry in missing.entries) {
      _badgeCache[entry.key] = await _buildBadge(
        entry.value.$1,
        entry.value.$2,
      );
    }
    if (mounted) setState(() {});
  }

  /// Canvas 自绘圆形徽标：白色描边 + 实心色点 → PNG bytes。
  static Future<BitmapDescriptor> _buildBadge(Color color, double size) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = Colors.white;
    canvas.drawCircle(center, size / 2, paint);
    paint.color = color;
    canvas.drawCircle(center, size / 2 - 1.5, paint);

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  BitmapDescriptor _iconFor(MapViewMarker marker) {
    final size = marker.isSelected ? _kBadgeSizeSelected : _kBadgeSizeNormal;
    final key = '${marker.color.toARGB32()}-$size';
    return _badgeCache[key] ??
        BitmapDescriptor.markerAnnotationWithHue(
          HSVColor.fromColor(marker.color).hue,
        );
  }

  @override
  Widget build(BuildContext context) {
    return AppleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          widget.initialCameraPosition.latitude,
          widget.initialCameraPosition.longitude,
        ),
        zoom: widget.initialCameraPosition.zoom,
      ),
      annotations: <Annotation>{
        for (final marker in widget.markers)
          Annotation(
            annotationId: AnnotationId('${marker.id}'),
            position: LatLng(marker.latitude, marker.longitude),
            icon: _iconFor(marker),
            zIndex: marker.isSelected ? 1 : 0,
            infoWindow: marker.calloutText == null
                ? InfoWindow.noText
                : InfoWindow(title: marker.calloutText),
            onTap: marker.onTap,
          ),
      },
      onTap: widget.onMapTapped == null
          ? null
          : (LatLng position) =>
                widget.onMapTapped?.call(position.latitude, position.longitude),
    );
  }
}
