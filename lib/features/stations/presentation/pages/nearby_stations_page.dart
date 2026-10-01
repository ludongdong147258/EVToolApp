import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ev_tool_app/core/constants/env.dart';
import 'package:ev_tool_app/core/domain/stations.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart';
import 'package:ev_tool_app/core/widgets/empty_state.dart';
import 'package:ev_tool_app/features/maps/presentation/widgets/apple_map_view.dart';
import 'package:ev_tool_app/features/stations/data/station_repository.dart';

/// 定位兜底（北京）。当前版本未接入定位 SDK（geolocator 未在依赖中），
/// 首次进入固定使用默认城市并展示提示条。
const double _defaultLatitude = 39.90923;
const double _defaultLongitude = 116.397428;

/// 默认地图缩放级别（1km 半径搜索结果可视）。
const double _mapZoom = 14;

/// 地图区占屏比例。
const double _mapHeightRatio = 0.4;

/// 附近充电桩（移植小程序 nearby-stations）。
///
/// 地图 + 周边充电桩列表（腾讯位置服务 place/search），marker/列表联动选中，
/// 导航经腾讯地图 routeplan 网页链接由 url_launcher 外部打开。
class NearbyStationsPage extends ConsumerStatefulWidget {
  const NearbyStationsPage({super.key});

  @override
  ConsumerState<NearbyStationsPage> createState() => _NearbyStationsPageState();
}

class _NearbyStationsPageState extends ConsumerState<NearbyStationsPage> {
  List<Station> _stations = const <Station>[];
  String? _selectedId;
  bool _loading = true;
  StationServiceException? _error;

  @override
  void initState() {
    super.initState();
    if (Env.hasLbsKey) {
      _loadStations();
    } else {
      _loading = false;
      _error = const StationServiceException('未配置地图服务 Key', isKeyMissing: true);
    }
  }

  /// 搜索充电桩（同位置 30 分钟内走缓存；[force] 手动刷新绕过）。
  Future<void> _loadStations({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedId = null;
    });
    try {
      final stations = await ref
          .read(stationRepositoryProvider)
          .searchNearbyStations(
            _defaultLatitude,
            _defaultLongitude,
            force: force,
          );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _stations = stations;
      });
    } on StationServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  /// marker 点击 → 联动选中列表项。
  void _selectStation(String stationId) {
    setState(() => _selectedId = stationId);
  }

  /// 唤起腾讯地图导航（外部浏览器打开 routeplan 链接）。
  Future<void> _navigateTo(Station station) async {
    final url = Uri.https('apis.map.qq.com', '/uri/v1/routeplan', {
      'type': 'drive',
      'to': station.name,
      'tocoord': '${station.latitude},${station.longitude}',
    });
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        showAppToast(context, '唤起导航失败');
      }
    } on Exception {
      if (mounted) {
        showAppToast(context, '唤起导航失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('附近充电桩'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _loadStations(force: true),
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DefaultLocationBar(),
          SizedBox(
            height: context.screenHeight * _mapHeightRatio,
            child: _buildMap(),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final palette = context.palette;
    return AppleMapView(
      initialCameraPosition: const MapViewCameraPosition(
        latitude: _defaultLatitude,
        longitude: _defaultLongitude,
        zoom: _mapZoom,
      ),
      markers: [
        for (var i = 0; i < _stations.length; i++)
          MapViewMarker(
            id: i,
            latitude: _stations[i].latitude,
            longitude: _stations[i].longitude,
            color: _stations[i].id == _selectedId
                ? palette.primary
                : AppColors.fastCharge,
            isSelected: _stations[i].id == _selectedId,
            calloutText: _stations[i].id == _selectedId
                ? _stations[i].name
                : null,
            onTap: () => _selectStation(_stations[i].id),
          ),
      ],
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('正在搜索附近充电桩…'),
          ],
        ),
      );
    }
    final error = _error;
    if (error != null) {
      final isKeyMissing = error.isKeyMissing;
      return SingleChildScrollView(
        child: EmptyState(
          icon: Icons.ev_station_outlined,
          title: isKeyMissing ? '位置服务未配置' : '加载失败',
          subtitle: isKeyMissing
              ? '需要在 .env 配置 TENCENT_LBS_KEY（腾讯位置服务 Key）后重启应用'
              : error.message,
          ctaText: isKeyMissing ? null : '重试',
          onCta: isKeyMissing ? null : () => _loadStations(force: true),
        ),
      );
    }
    if (_stations.isEmpty) {
      return const SingleChildScrollView(
        child: EmptyState(
          icon: Icons.ev_station_outlined,
          title: '附近暂无充电桩',
          subtitle: '可尝试点击右上角刷新，或移动到其他区域',
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _stations.length,
      itemBuilder: (context, index) {
        final station = _stations[index];
        final isSelected = station.id == _selectedId;
        return _StationTile(
          station: station,
          isSelected: isSelected,
          onTap: () => _openStationSheet(station),
        );
      },
    );
  }

  /// 列表项点击 → 选中并弹出站点详情 + 导航入口。
  Future<void> _openStationSheet(Station station) async {
    _selectStation(station.id);
    await showAppSheet(
      context: context,
      title: station.name,
      builder: (_) => AppSheetScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (station.address.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  station.address,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ),
            if (station.distance != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '距离 ${formatDistance(station.distance)}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ),
            if (station.category.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _CategoryTag(station.category),
                ),
              ),
            FilledButton.icon(
              onPressed: () => _navigateTo(station),
              icon: const Icon(Icons.navigation_outlined, size: 18),
              label: const Text('打开导航'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部提示条：未获取定位，展示默认位置。
class _DefaultLocationBar extends StatelessWidget {
  const _DefaultLocationBar();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: palette.secondaryContainer.withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(Icons.place_outlined, size: 14, color: palette.textHint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '未获取定位，展示默认位置（北京）',
              style: context.textTheme.bodySmall?.copyWith(
                color: palette.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 站点列表条目：图标 + 名称 + 距离 + 地址 + 分类标签。
class _StationTile extends StatelessWidget {
  const _StationTile({
    required this.station,
    required this.isSelected,
    required this.onTap,
  });

  final Station station;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? palette.secondaryContainer.withValues(alpha: 0.6)
            : palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.ev_station_outlined,
                  size: 20,
                  color: isSelected ? palette.primary : palette.textHint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              station.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (station.distance != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              formatDistance(station.distance),
                              style: context.textTheme.bodySmall?.copyWith(
                                color: palette.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (station.address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          station.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: palette.textHint,
                          ),
                        ),
                      ],
                      if (station.category.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _CategoryTag(station.category),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 分类标签（LBS POI category，如「充电桩」）。
class _CategoryTag extends StatelessWidget {
  const _CategoryTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: palette.textSecondary),
      ),
    );
  }
}
