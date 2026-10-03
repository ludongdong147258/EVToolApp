import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ev_tool_app/core/constants/env.dart';
import 'package:ev_tool_app/core/domain/stations.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/utils/coord_convert.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart';
import 'package:ev_tool_app/core/widgets/empty_state.dart';
import 'package:ev_tool_app/features/maps/presentation/widgets/apple_map_view.dart';
import 'package:ev_tool_app/features/stations/data/station_repository.dart';

/// 定位失败/未授权时的兜底坐标（北京），同时展示顶部提示条。
const double _defaultLatitude = 39.90923;
const double _defaultLongitude = 116.397428;

/// 默认地图缩放级别（1km 半径搜索结果可视）。
const double _mapZoom = 14;

/// 地图区占屏比例。
const double _mapHeightRatio = 0.4;

/// 附近充电桩（移植小程序 nearby-stations）。
///
/// 地图 + 周边充电桩列表（腾讯位置服务 place/search），marker/列表联动选中，
/// 导航/电话咨询内嵌条目（选中展开），导航唤起系统 Apple 地图。
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
  double _latitude = _defaultLatitude;
  double _longitude = _defaultLongitude;

  /// 仍在使用兜底坐标（未定位成功）时展示提示条。
  bool _isDefaultLocation = true;

  /// 列表条目 key：marker 点击联动滚动用（数据刷新时清空）。
  final Map<String, GlobalKey> _tileKeys = <String, GlobalKey>{};

  /// 列表滚动控制器（条目未构建时的估算兜底用）。
  final ScrollController _listController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (Env.hasLbsKey) {
      _locateThenLoad();
    } else {
      _loading = false;
      _error = const StationServiceException(
        'Map service key not configured',
        isKeyMissing: true,
      );
    }
  }

  /// 进页自动定位当前位置后搜索；定位失败/拒绝则用北京兜底照常搜索。
  Future<void> _locateThenLoad() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final granted =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      if (granted) {
        final position = await Geolocator.getCurrentPosition();
        // iOS 返回 WGS-84，地图与腾讯 LBS 均为 GCJ-02
        final gcj = wgs84ToGcj02(position.latitude, position.longitude);
        if (mounted) {
          setState(() {
            _latitude = gcj.latitude;
            _longitude = gcj.longitude;
            _isDefaultLocation = false;
          });
        }
      }
    } on Exception {
      // 定位不可用（模拟器/未授权）→ 保持北京兜底
    }
    await _loadStations();
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
          .searchNearbyStations(_latitude, _longitude, force: force);
      if (!mounted) return;
      _tileKeys.clear();
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

  /// marker 点击 → 联动选中列表项并滚动到位（对齐小程序 scrollIntoView）。
  void _selectStation(String stationId) {
    setState(() => _selectedId = stationId);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToStation(stationId),
    );
  }

  /// 列表平滑滚动到选中条目（视口上部 20% 处，展开操作行后仍可见）。
  void _scrollToStation(String stationId) {
    if (!mounted) return;
    final tileContext = _tileKeys[stationId]?.currentContext;
    if (tileContext != null) {
      Scrollable.ensureVisible(
        tileContext,
        duration: const Duration(milliseconds: 250),
        alignment: 0.2,
      );
      return;
    }
    // 条目在屏外未被 builder 构建：按平均条目高估算近似位置
    final index = _stations.indexWhere((station) => station.id == stationId);
    if (index < 0 || !_listController.hasClients) return;
    final position = _listController.position;
    if (!position.hasContentDimensions) return;
    final target =
        (index * _approxTileHeight - position.viewportDimension * 0.2).clamp(
          0.0,
          position.maxScrollExtent,
        );
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  /// 列表条目估算高度（未选中态 ~72 + 间距 8）。
  static const double _approxTileHeight = 80;

  /// 列表项点击 → 选中展开操作行；再点已选中项收起。
  void _toggleStation(String stationId) {
    setState(() => _selectedId = _selectedId == stationId ? null : stationId);
  }

  /// 拨打站点电话（无电话按钮不展示，此处 tel 必非空）。
  Future<void> _callStation(Station station) async {
    try {
      final launched = await launchUrl(
        Uri(scheme: 'tel', path: station.tel),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        showAppToast(context, 'Call failed');
      }
    } on Exception {
      if (mounted) {
        showAppToast(context, 'Call failed');
      }
    }
  }

  /// 唤起系统自带 Apple 地图导航。
  Future<void> _navigateTo(Station station) async {
    final url = Uri.https('maps.apple.com', '/', {
      'daddr': '${station.latitude},${station.longitude}',
      'q': station.name,
    });
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        showAppToast(context, 'Failed to open navigation');
      }
    } on Exception {
      if (mounted) {
        showAppToast(context, 'Failed to open navigation');
      }
    }
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Stations'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _loadStations(force: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isDefaultLocation) const _DefaultLocationBar(),
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
      // 插件只认 initial camera：定位后靠 key 重建地图落到新视野
      key: ValueKey('$_latitude,$_longitude'),
      initialCameraPosition: MapViewCameraPosition(
        latitude: _latitude,
        longitude: _longitude,
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
            Text('Searching for nearby charging stations…'),
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
          title: isKeyMissing
              ? 'Location service not configured'
              : 'Failed to load',
          subtitle: isKeyMissing
              ? 'Set TENCENT_LBS_KEY (Tencent LBS key) in .env and restart the app'
              : error.message,
          ctaText: isKeyMissing ? null : 'Retry',
          onCta: isKeyMissing ? null : () => _loadStations(force: true),
        ),
      );
    }
    if (_stations.isEmpty) {
      return const SingleChildScrollView(
        child: EmptyState(
          icon: Icons.ev_station_outlined,
          title: 'No charging stations nearby',
          subtitle:
              'Try the refresh button in the top right, or move to another area',
        ),
      );
    }
    return ListView.builder(
      controller: _listController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _stations.length,
      itemBuilder: (context, index) {
        final station = _stations[index];
        final isSelected = station.id == _selectedId;
        return _StationTile(
          key: _tileKeys.putIfAbsent(station.id, GlobalKey.new),
          station: station,
          isSelected: isSelected,
          onTap: () => _toggleStation(station.id),
          onNavigate: () => _navigateTo(station),
          onCall: station.tel.isEmpty ? null : () => _callStation(station),
        );
      },
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
              'Location unavailable — showing the default area (Beijing)',
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

/// 站点列表条目：图标 + 名称 + 距离 + 地址 + 分类标签；
/// 选中态展开操作行（导航 / 电话咨询，对齐小程序 .nbs-item-actions）。
class _StationTile extends StatelessWidget {
  const _StationTile({
    super.key,
    required this.station,
    required this.isSelected,
    required this.onTap,
    required this.onNavigate,
    this.onCall,
  });

  final Station station;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onNavigate;
  final VoidCallback? onCall;

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
                              '${formatDistance(station.distance)} away',
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
                      if (isSelected) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _NavButton(onTap: onNavigate),
                            if (onCall != null) ...[
                              const SizedBox(width: 8),
                              _CallButton(tel: station.tel, onTap: onCall!),
                            ],
                          ],
                        ),
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

/// 导航小按钮（对齐小程序 .btn-primary 口径的紧凑版）。
class _NavButton extends StatelessWidget {
  const _NavButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: palette.primaryContainer,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Navigate',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 电话咨询描边按钮（对齐小程序 .btn-outline）。
class _CallButton extends StatelessWidget {
  const _CallButton({required this.tel, required this.onTap});

  final String tel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: palette.primaryContainer),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        child: Text(
          'Call $tel',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: palette.primaryContainer,
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
