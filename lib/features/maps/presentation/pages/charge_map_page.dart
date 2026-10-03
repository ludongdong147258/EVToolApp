import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ev_tool_app/core/domain/charge_map.dart';
import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/domain/vehicles.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/routing/route_names.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart';
import 'package:ev_tool_app/core/widgets/empty_state.dart';
import 'package:ev_tool_app/core/widgets/gradient_hero_card.dart';
import 'package:ev_tool_app/features/maps/presentation/widgets/apple_map_view.dart';
import 'package:ev_tool_app/features/records/presentation/providers/records_provider.dart';

/// 地图区高度：屏高 46%（最小 280，对齐小程序 46vh / 560rpx）。
const double _mapHeightRatio = 0.46;
const double _mapHeightMin = 280;

/// 高频城市条形卡取前 N 名。
const int _cityTopN = 3;

/* 时间范围选项（key → filterRecords 的 monthKey/year 入参） */
const List<({String key, String text})> _rangeOptions = [
  (key: 'all', text: 'All'),
  (key: 'year', text: 'This Year'),
  (key: 'month', text: 'This Month'),
];

/* 类型选项（null = 全部） */
const List<({String? key, String text})> _typeOptions = [
  (key: null, text: 'All'),
  (key: 'home', text: 'Home (AC)'),
  (key: 'fast', text: 'Fast (DC)'),
];

/// 充电点位地图（移植小程序 charge-map）。
///
/// 个人充电地点分布回顾：散点标记（家充绿点 / 快充橙点），无路线绘制；
/// 渐变 Hero 统计卡 + 高频城市条形；不申请定位权限（点位均为手动录入）。
class ChargeMapPage extends ConsumerStatefulWidget {
  const ChargeMapPage({super.key});

  @override
  ConsumerState<ChargeMapPage> createState() => _ChargeMapPageState();
}

class _ChargeMapPageState extends ConsumerState<ChargeMapPage> {
  String? _vehicleFilter; // null = 全部车辆
  String? _typeFilter; // null | "fast" | "home"
  String _rangeFilter = 'all'; // "all" | "year" | "month"
  String? _selectedKey; // 选中点位（groups.key），驱动标注气泡
  MapViewport _viewport = const MapViewport(
    latitude: mapFallbackLatitude,
    longitude: mapFallbackLongitude,
    zoom: 4,
  );
  bool _centerLocked = false; // 首次定位后锁定，切筛选不重置视野

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(recordsProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final filtered = _filterRecords(records);
    final groups = groupRecordsByLocation(filtered);
    final stats = calcLocationStats(filtered);
    final cityTop = calcCityTop(filtered, _cityTopN);

    final viewport = _centerLocked
        ? _viewport
        : getMapCenter(
            filtered,
            fallbackLatitude: mapFallbackLatitude,
            fallbackLongitude: mapFallbackLongitude,
          );
    if (!_centerLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _viewport = viewport;
          _centerLocked = true;
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Charging Map')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilterRow(vehicles),
            const SizedBox(height: 12),
            _buildMap(groups, viewport),
            const SizedBox(height: 16),
            if (groups.isEmpty)
              _buildMapEmpty(records)
            else ...[
              _buildHeroStats(groups, stats),
              if (cityTop.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildCityTopCard(cityTop),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /* --- 数据推导 --- */

  List<ChargeRecord> _filterRecords(List<ChargeRecord> records) {
    final now = DateTime.now();
    final String? monthKey = _rangeFilter == 'month'
        ? getCurrentMonthKey(now: now)
        : null;
    final String? year = _rangeFilter == 'year' ? '${now.year}' : null;
    return filterRecords(
      records,
      RecordFilters(
        monthKey: monthKey,
        year: year,
        type: _typeFilter,
        vehicleId: _vehicleFilter,
      ),
    );
  }

  /* --- 筛选 --- */

  void _handleVehicleFilter(String vehicleId) {
    setState(() {
      _vehicleFilter = _vehicleFilter == vehicleId ? null : vehicleId;
    });
  }

  void _handleTypeFilter(String? type) {
    setState(() {
      _typeFilter = type;
    });
  }

  void _handleRangeFilter(String range) {
    setState(() {
      _rangeFilter = range;
    });
  }

  /* --- 地图与点位 --- */

  Widget _buildFilterRow(List<Vehicle> vehicles) {
    final vehicleOptions = [
      for (final vehicle in vehicles) (key: vehicle.id, text: vehicle.name),
    ];
    return SizedBox(
      height: 28,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const _FilterLabel('Time'),
          for (final option in _rangeOptions)
            _FilterChip(
              text: option.text,
              active: _rangeFilter == option.key,
              onTap: () => _handleRangeFilter(option.key),
            ),
          const _FilterLabel('Type', indent: true),
          for (final option in _typeOptions)
            _FilterChip(
              text: option.text,
              active: _typeFilter == option.key,
              onTap: () => _handleTypeFilter(option.key),
            ),
          if (vehicleOptions.isNotEmpty) ...[
            const _FilterLabel('Vehicle', indent: true),
            for (final option in vehicleOptions)
              _FilterChip(
                text: option.text,
                active: _vehicleFilter == option.key,
                onTap: () => _handleVehicleFilter(option.key),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMap(List<LocationGroup> groups, MapViewport viewport) {
    final palette = context.palette;
    final markers = buildLocationMarkers(groups, selectedKey: _selectedKey);
    final height = (MediaQuery.sizeOf(context).height * _mapHeightRatio).clamp(
      _mapHeightMin,
      double.infinity,
    );
    // 卡片化地图：细边框 + 软阴影（对齐小程序 .cm-map-wrap）
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: palette.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        child: Stack(
          children: [
            Positioned.fill(
              child: AppleMapView(
                initialCameraPosition: MapViewCameraPosition(
                  latitude: viewport.latitude,
                  longitude: viewport.longitude,
                  zoom: viewport.zoom,
                ),
                markers: [
                  for (final marker in markers)
                    MapViewMarker(
                      id: marker.id,
                      latitude: marker.latitude,
                      longitude: marker.longitude,
                      color: marker.isHome
                          ? AppColors.homeCharge
                          : AppColors.fastCharge,
                      isSelected: marker.isSelected,
                      calloutText: marker.calloutText,
                      onTap: () => _openGroupSheet(groups[marker.id]),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: _MapLegend(pointCount: groups.length),
            ),
          ],
        ),
      ),
    );
  }

  /// marker 点击 → 弹出该点位记录列表。
  Future<void> _openGroupSheet(LocationGroup group) async {
    setState(() => _selectedKey = group.key);
    await showAppSheet(
      context: context,
      title: '${group.locationName} · ${group.count} charges',
      builder: (_) => AppSheetScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final record in group.records)
              _GroupRecordTile(
                record: record,
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('${RouteNames.recordAdd}?id=${record.id}');
                },
              ),
            const SizedBox(height: 12),
            // 填充式导航按钮（对齐小程序 .btn-primary）
            FilledButton.icon(
              onPressed: () => _navigateTo(group),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Navigate There'),
            ),
          ],
        ),
      ),
    );
    if (mounted) {
      setState(() => _selectedKey = null);
    }
  }

  /// 唤起系统自带 Apple 地图导航（group 坐标为用户录入的真实点位坐标）。
  Future<void> _navigateTo(LocationGroup group) async {
    final url = Uri.https('maps.apple.com', '/', {
      'daddr': '${group.latitude},${group.longitude}',
      'q': group.locationName,
    });
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        showAppToast(context, 'Could not open Maps');
      }
    } on Exception {
      if (mounted) {
        showAppToast(context, 'Could not open Maps');
      }
    }
  }

  void _goAddRecord() {
    context.push(RouteNames.recordAdd);
  }

  /* --- 统计面板 --- */

  Widget _buildHeroStats(List<LocationGroup> groups, LocationStats stats) {
    return GradientHeroCard(
      // 紧凑 padding（对齐小程序 .cm-hero）
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: HeroStatsRow(
        items: [
          HeroStatItem(label: 'Locations', value: '${groups.length}'),
          HeroStatItem(label: 'Charges', value: '${stats.recordCount}'),
          HeroStatItem(label: 'Home %', value: '${stats.homeRatio}%'),
          HeroStatItem(label: 'Fast %', value: '${stats.fastRatio}%'),
        ],
      ),
    );
  }

  Widget _buildCityTopCard(List<({String city, int count})> cityTop) {
    final maxCount = cityTop.first.count;
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Charging Cities', style: context.textTheme.titleSmall),
          const SizedBox(height: 12),
          for (var i = 0; i < cityTop.length; i++)
            _CityTopItem(
              rank: i + 1,
              city: cityTop[i].city,
              count: cityTop[i].count,
              percent: maxCount > 0 ? cityTop[i].count / maxCount : 0,
            ),
        ],
      ),
    );
  }

  /* --- 空态 --- */

  Widget _buildMapEmpty(List<ChargeRecord> records) {
    final hasLocatedEver = records.any(
      (record) => record.latitude != null && record.longitude != null,
    );
    return EmptyState(
      icon: Icons.place_outlined,
      title: hasLocatedEver
          ? 'No locations for this filter'
          : 'No locations yet',
      subtitle: hasLocatedEver
          ? 'Try a different time range or vehicle'
          : 'Add a charging record with a location to see it on the map',
      ctaText: hasLocatedEver ? null : 'Add Record',
      onCta: hasLocatedEver ? null : _goAddRecord,
    );
  }
}

/// 筛选行前缀文案（时间 / 类型 / 车辆）。
class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.text, {this.indent = false});

  final String text;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent ? 12 : 4, right: 8),
      child: Center(
        child: Text(
          text,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.palette.textHint,
          ),
        ),
      ),
    );
  }
}

/// 筛选 chip（chip--sm 小号胶囊，与养车支出/充电统计同款）。
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.text,
    required this.active,
    required this.onTap,
  });

  final String text;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: active ? palette.secondaryContainer : palette.inputBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? palette.primaryContainer : Colors.transparent,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: active
                  ? palette.onSecondaryContainer
                  : palette.onSurfaceVariant,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// 地图左下角图例：颜色含义 + 当前点位数。
class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.pointCount});

  final int pointCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surfaceCard.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _LegendDot(AppColors.homeCharge),
          const SizedBox(width: 4),
          Text('Home', style: context.textTheme.bodySmall),
          const SizedBox(width: 8),
          const _LegendDot(AppColors.fastCharge),
          const SizedBox(width: 4),
          Text('Fast', style: context.textTheme.bodySmall),
          const SizedBox(width: 8),
          Text(
            '$pointCount points',
            style: context.textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
    );
  }
}

/// 高频城市条目：名次徽标 + 城市名 + 次数条形（长度相对 TOP1）。
class _CityTopItem extends StatelessWidget {
  const _CityTopItem({
    required this.rank,
    required this.city,
    required this.count,
    required this.percent,
  });

  final int rank;
  final String city;
  final int count;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isFirst = rank == 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isFirst
                  ? palette.primary.withValues(alpha: 0.08)
                  : palette.inputBg,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isFirst ? palette.secondary : palette.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '$count charges',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: palette.textHint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        Container(
                          color: palette.primary.withValues(alpha: 0.08),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: percent.clamp(0, 1),
                          child: Container(color: palette.primaryContainer),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 弹层内记录卡片：日期 + 类型 pill + 金额行 + 备注，点击跳编辑。
class _GroupRecordTile extends StatelessWidget {
  const _GroupRecordTile({required this.record, required this.onTap});

  final ChargeRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isHome = record.type == 'home';
    final typeColor = isHome ? AppColors.homeCharge : AppColors.fastCharge;
    final costPerKwh = calcCostPerKwh(record.cost, record.energy);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: palette.inputBg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.date,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        typeDefaultTitles[record.type] ?? record.type,
                        style: TextStyle(fontSize: 11, color: typeColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatMoney(record.cost)} · ${record.energy} kWh'
                  '${costPerKwh == null ? '' : ' · ${formatMoney(costPerKwh)}/kWh'}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: palette.onSurface,
                  ),
                ),
                if (record.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    record.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: palette.textHint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
