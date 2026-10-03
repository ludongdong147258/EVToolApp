import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/charge_map.dart'
    show mapFallbackLatitude, mapFallbackLongitude;
import 'package:ev_tool_app/core/domain/charge_records.dart'
    show locationNameMaxLength;
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/features/maps/presentation/widgets/apple_map_view.dart';
import 'package:ev_tool_app/features/records/data/geocoding_repository.dart';

/// 地图选点结果（充电记录表单回填用）。
class PickedLocation {
  const PickedLocation({
    required this.latitude,
    required this.longitude,
    this.province,
    this.city,
    this.locationName,
  });

  final double latitude;
  final double longitude;
  final String? province;
  final String? city;
  final String? locationName;
}

/// 地图选点页：点击地图放置 marker，逆地理补全省市/地点名。
///
/// 逆地理走 CLGeocoder（GeocodingRepository，设备端 Apple 服务）；
/// 失败（无网/无结果）时降级为只保存坐标（不阻塞选点）。
/// 注意：包含地图插件，不可在 flutter test 中 pump。
class LocationPickerPage extends ConsumerStatefulWidget {
  const LocationPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  /// 初始视野（编辑记录时传当前点位）。
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  ConsumerState<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends ConsumerState<LocationPickerPage> {
  double? _latitude;
  double? _longitude;

  /// 逆地理解析中的地点名（null = 未选点；'' = 解析中）。
  String? _resolving;
  PickedLocation? _resolved;

  /// 逆地理失败（无网/无结果）→ 只回填坐标时置位，
  /// 底部预览提示用户详细地址缺失。
  bool _geocodeFailed = false;

  void _handleMapTap(double latitude, double longitude) {
    setState(() {
      _latitude = latitude;
      _longitude = longitude;
      _resolving = '';
      _resolved = null;
    });
    _resolveLocation(latitude, longitude);
  }

  Future<void> _resolveLocation(double latitude, double longitude) async {
    // CLGeocoder 逆地理；失败返回 null → 只保存坐标
    final region = await ref
        .read(geocodingRepositoryProvider)
        .reverseGeocode(latitude, longitude);
    if (!mounted || _latitude != latitude || _longitude != longitude) return;
    setState(() {
      _geocodeFailed = region == null;
      if (region != null && region.province.isNotEmpty) {
        _resolved = PickedLocation(
          latitude: latitude,
          longitude: longitude,
          province: region.province,
          city: region.city.isNotEmpty ? region.city : null,
          // POI 标题优先，缺失时回退街道地址
          locationName: _truncateLocation(
            region.poiTitle.isNotEmpty ? region.poiTitle : region.address,
          ),
        );
      } else {
        _resolved = PickedLocation(latitude: latitude, longitude: longitude);
      }
      _resolving = null;
    });
  }

  String? _truncateLocation(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length <= locationNameMaxLength
        ? trimmed
        : trimmed.substring(0, locationNameMaxLength);
  }

  void _confirm() {
    final resolved = _resolved;
    if (resolved == null) return;
    Navigator.of(context).pop(resolved);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final latitude = _latitude;
    final longitude = _longitude;
    final hasPicked = latitude != null && longitude != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Location')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: AppleMapView(
                    initialCameraPosition: MapViewCameraPosition(
                      latitude: widget.initialLatitude ?? mapFallbackLatitude,
                      longitude:
                          widget.initialLongitude ?? mapFallbackLongitude,
                      zoom: widget.initialLatitude != null ? 14 : 11,
                    ),
                    markers: hasPicked
                        ? [
                            MapViewMarker(
                              id: 0,
                              latitude: latitude,
                              longitude: longitude,
                              color: palette.primary,
                              isSelected: true,
                            ),
                          ]
                        : const <MapViewMarker>[],
                    onMapTapped: _handleMapTap,
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceCard.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                    child: Text(
                      hasPicked
                          ? 'Tap the map to adjust'
                          : 'Tap the map to choose a location',
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _bottomText(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: hasPicked ? palette.onSurface : palette.textHint,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _resolved == null ? null : _confirm,
                    child: Text(_resolving == null ? 'Confirm' : 'Resolving…'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _bottomText() {
    final resolved = _resolved;
    if (_resolving == '') {
      return 'Resolving the address of the selected spot…';
    }
    if (resolved != null) {
      final parts = [
        if (resolved.city != null || resolved.province != null)
          [resolved.province, resolved.city].whereType<String>().join(' · '),
        if (resolved.locationName != null) resolved.locationName,
      ];
      final text = parts.join(' ');
      if (text.isEmpty) return 'Location selected';
      return _geocodeFailed
          ? '$text (no detailed address found; location name may be incomplete)'
          : text;
    }
    return 'No location selected yet';
  }
}
