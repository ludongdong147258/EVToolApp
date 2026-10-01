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

/// 地图标注点（color 由封装层映射为插件 pin 色相；
/// [isSelected] 提升层级并显示 [calloutText] 气泡）。
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
class AppleMapView extends StatelessWidget {
  const AppleMapView({
    super.key,
    required this.initialCameraPosition,
    this.markers = const <MapViewMarker>[],
    this.onMapTapped,
  });

  final MapViewCameraPosition initialCameraPosition;
  final List<MapViewMarker> markers;
  final VoidCallback? onMapTapped;

  @override
  Widget build(BuildContext context) {
    return AppleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          initialCameraPosition.latitude,
          initialCameraPosition.longitude,
        ),
        zoom: initialCameraPosition.zoom,
      ),
      annotations: <Annotation>{
        for (final marker in markers)
          Annotation(
            annotationId: AnnotationId('${marker.id}'),
            position: LatLng(marker.latitude, marker.longitude),
            icon: BitmapDescriptor.markerAnnotationWithHue(
              HSVColor.fromColor(marker.color).hue,
            ),
            zIndex: marker.isSelected ? 1 : 0,
            infoWindow: marker.calloutText == null
                ? InfoWindow.noText
                : InfoWindow(title: marker.calloutText),
            onTap: marker.onTap,
          ),
      },
      onTap: onMapTapped == null
          ? null
          : (LatLng position) => onMapTapped?.call(),
    );
  }
}
