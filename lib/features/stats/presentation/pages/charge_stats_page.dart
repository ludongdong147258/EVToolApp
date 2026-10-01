import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/core/domain/export_data.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/domain/vehicles.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/routing/route_names.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart';
import 'package:ev_tool_app/core/widgets/empty_state.dart';
import 'package:ev_tool_app/core/widgets/gradient_hero_card.dart';
import 'package:ev_tool_app/core/widgets/undo_bar.dart';
import 'package:ev_tool_app/features/records/presentation/providers/records_provider.dart';
import 'package:ev_tool_app/features/records/presentation/widgets/record_card.dart';
import 'package:ev_tool_app/features/records/presentation/widgets/record_detail_sheet.dart';

/// 类型筛选 chips（null = 全部）。
const List<(String?, String)> _typeFilters = <(String?, String)>[
  (null, '全部'),
  ('fast', '快充'),
  ('home', '家充'),
];

/// 充电统计页（子页，从「我的 → 充电统计」进入）：
/// 累计/本月概览 + 月份筛选列表（移植小程序 charge-stats 页）。
class ChargeStatsPage extends ConsumerStatefulWidget {
  const ChargeStatsPage({super.key});

  @override
  ConsumerState<ChargeStatsPage> createState() => _ChargeStatsPageState();
}

class _ChargeStatsPageState extends ConsumerState<ChargeStatsPage> {
  String _monthKey = getCurrentMonthKey();
  String? _typeFilter;
  String? _vehicleFilter;
  List<ChargeRecord> _deletedPending = [];
  bool _undoFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 从记录/新增/车辆页返回时刷新（删除、新增、改名后数据保持同步）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(recordsProvider.notifier).reload();
        ref.read(vehiclesProvider.notifier).reload();
      }
    });
  }

  List<ChargeRecord> _filterMonthRecords(
    List<ChargeRecord> records,
    String monthKey,
  ) {
    return filterRecords(
      records,
      RecordFilters(
        monthKey: monthKey,
        type: _typeFilter,
        vehicleId: _vehicleFilter,
      ),
    );
  }

  /* ---------- 详情 / 删除（与记录页同一撤销模式） ---------- */

  Future<void> _openDetail(ChargeRecord record) async {
    await showRecordDetailSheet(
      context,
      record: record,
      onEdit: () => context.push('${RouteNames.recordAdd}?id=${record.id}'),
      onDelete: () => _confirmDelete(record.id),
    );
  }

  Future<void> _confirmDelete(String id) async {
    unawaited(HapticFeedback.lightImpact());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('删除后 5 秒内可在底部提示条撤销，确定删除这条记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.palette.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _removeRecord(id);
  }

  Future<void> _removeRecord(String id) async {
    final deleted = await ref.read(recordsProvider.notifier).remove(id);
    if (deleted == null || !mounted) return;
    setState(() {
      _deletedPending = [..._deletedPending, deleted];
      _undoFailed = false;
    });
    _showUndoBar();
  }

  void _showUndoBar() {
    showUndoBar(
      context,
      text: _undoFailed ? '恢复失败，点此重试' : '已删除 ${_deletedPending.length} 条充电记录',
      actionText: _undoFailed ? '重试' : '撤销',
      onUndo: _undoDelete,
    ).closed.whenComplete(() {
      // 窗口关闭（超时或撤销后）即放弃剩余待恢复项
      if (mounted) {
        setState(() {
          _deletedPending = [];
          _undoFailed = false;
        });
      }
    });
  }

  Future<void> _undoDelete() async {
    final pending = _deletedPending;
    if (pending.isEmpty) return;
    final allOk = await ref.read(recordsProvider.notifier).restoreAll(pending);
    if (!mounted) return;
    setState(() => _undoFailed = !allOk);
    if (allOk) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('已恢复')));
      _deletedPending = [];
    }
  }

  /* ---------- 月份 / 筛选 ---------- */

  void _goPrevMonth(List<String> availableMonths) {
    final oldest = availableMonths.isEmpty ? null : availableMonths.last;
    final prev = shiftMonthKey(_monthKey, -1);
    if (prev == null || oldest == null || prev.compareTo(oldest) < 0) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _monthKey = prev);
  }

  void _goNextMonth() {
    final next = shiftMonthKey(_monthKey, 1);
    if (next == null || next.compareTo(getCurrentMonthKey()) > 0) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _monthKey = next);
  }

  /* ---------- 导出 / 复制小结 ---------- */

  /// 当前筛选月份的月度小结文案（复制共用）。
  String _buildMonthText(List<ChargeRecord> records) {
    final monthRecords = _filterMonthRecords(records, _monthKey);
    return buildMonthSummaryText(
      calcMonthSummary(monthRecords, _monthKey),
      formatMonthLabel(_monthKey),
    );
  }

  Future<void> _openExportSheet(
    List<ChargeRecord> records,
    List<Vehicle> vehicles,
  ) async {
    await showAppSheet<void>(
      context: context,
      title: '导出数据',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              Icons.grid_on_rounded,
              color: sheetContext.palette.primary,
            ),
            title: const Text('导出全部 CSV'),
            subtitle: const Text('充电记录与车辆，通过系统分享导出'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              unawaited(_exportCsv(records, vehicles));
            },
          ),
          ListTile(
            leading: Icon(
              Icons.content_copy_rounded,
              color: sheetContext.palette.primary,
            ),
            title: const Text('复制本月小结'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              unawaited(_copyMonthSummary(records));
            },
          ),
        ],
      ),
    );
  }

  /// CSV 导出全部数据（不受筛选影响）：记录 + 车辆两个临时文件一起分享。
  Future<void> _exportCsv(
    List<ChargeRecord> records,
    List<Vehicle> vehicles,
  ) async {
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final recordFile = File('${dir.path}/evtool_records_$stamp.csv');
      final vehicleFile = File('${dir.path}/evtool_vehicles_$stamp.csv');
      await recordFile.writeAsString(recordsToCsv(records));
      await vehicleFile.writeAsString(vehiclesToCsv(vehicles));
      await Share.shareXFiles([
        XFile(recordFile.path),
        XFile(vehicleFile.path),
      ]);
    } on Exception catch (err) {
      appLogger.e('导出 CSV 失败', error: err);
      if (mounted) showAppToast(context, '导出失败，请重试');
    }
  }

  Future<void> _copyMonthSummary(List<ChargeRecord> records) async {
    try {
      await Clipboard.setData(ClipboardData(text: _buildMonthText(records)));
      if (mounted) showAppToast(context, '已复制到剪贴板');
    } on Exception catch (err) {
      appLogger.e('复制本月小结失败', error: err);
      if (mounted) showAppToast(context, '复制失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final records = ref.watch(recordsProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final total = calcTotalSummary(records);
    final currentMonthKey = getCurrentMonthKey();
    final monthLabel = formatMonthLabel(_monthKey);
    final isCurrentMonth = _monthKey == currentMonthKey;

    /* 月份切换边界：不早于最早有记录月、不晚于当前月 */
    final availableMonths = getAvailableMonths(records);
    final oldestMonth = availableMonths.isEmpty ? null : availableMonths.last;
    final canGoPrev =
        oldestMonth != null && _monthKey.compareTo(oldestMonth) > 0;
    final canGoNext = _monthKey.compareTo(currentMonthKey) < 0;

    /* 月卡随筛选联动：筛选结果既算月度汇总也渲染列表 */
    final monthRecords = _filterMonthRecords(records, _monthKey);
    final month = calcMonthSummary(monthRecords, _monthKey);

    return Scaffold(
      appBar: AppBar(title: const Text('充电统计')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // 累计概览卡（渐变 hero，白字数据区）
          GradientHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '累计充电支出',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onPrimaryA85,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                HeroValue(value: formatYuan(total.totalCost), unit: '¥'),
                const SizedBox(height: 16),
                HeroStatsRow(
                  items: [
                    HeroStatItem(
                      label: '充电次数',
                      value: '${total.count}',
                      unit: '次',
                    ),
                    HeroStatItem(
                      label: '累计电量',
                      value: formatYuan(total.totalEnergy),
                      unit: 'kWh',
                    ),
                    HeroStatItem(
                      label: '度电成本',
                      value: total.costPerKwh == null
                          ? '--'
                          : formatYuan(total.costPerKwh!),
                      unit: '¥/kWh',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 月度概览（浅色卡，含月份切换）
          _MonthCard(
            monthLabel: monthLabel,
            isCurrentMonth: isCurrentMonth,
            canGoPrev: canGoPrev,
            canGoNext: canGoNext,
            onPrev: () => _goPrevMonth(availableMonths),
            onNext: _goNextMonth,
            totalCost: month.totalCost,
            count: month.count,
            costPerKwh: month.costPerKwh,
          ),
          const SizedBox(height: 12),

          // 类型 / 车辆筛选
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in _typeFilters)
                _FilterChip(
                  label: label,
                  isSelected: _typeFilter == value,
                  onTap: () => setState(() => _typeFilter = value),
                ),
              for (final vehicle in vehicles)
                _FilterChip(
                  label: vehicle.name,
                  isSelected: _vehicleFilter == vehicle.id,
                  onTap: () => setState(
                    () => _vehicleFilter = _vehicleFilter == vehicle.id
                        ? null
                        : vehicle.id,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 年度报告入口卡
          _ReportEntryCard(onTap: () => context.push(RouteNames.annualReport)),
          const SizedBox(height: 12),

          // 月份记录列表 / 空态
          Row(
            children: [
              Expanded(
                child: Text(
                  '$monthLabel · ${monthRecords.length} 条',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (records.isNotEmpty)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => unawaited(_openExportSheet(records, vehicles)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.save_outlined,
                          size: 16,
                          color: palette.textHint,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '导出',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (records.isEmpty)
            EmptyState(
              icon: Icons.insights_rounded,
              title: '暂无充电数据',
              subtitle: '去充电记录页添加记录，这里将展示统计',
              ctaText: '去添加记录',
              onCta: () => context.go(RouteNames.records),
            )
          else if (monthRecords.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.search_off_rounded,
              title: '本月暂无符合条件的记录',
            )
          else
            for (final record in monthRecords)
              RecordCard(
                record: record,
                vehicles: vehicles,
                onOpen: (id) {
                  final target = records
                      .where((item) => item.id == id)
                      .firstOrNull;
                  if (target != null) _openDetail(target);
                },
                onEdit: (id) => context.push('${RouteNames.recordAdd}?id=$id'),
                onDelete: _confirmDelete,
              ),
        ],
      ),
    );
  }
}

/// 月度概览卡（浅色卡 + 月份切换箭头）。
class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.monthLabel,
    required this.isCurrentMonth,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
    required this.totalCost,
    required this.count,
    required this.costPerKwh,
  });

  final String monthLabel;
  final bool isCurrentMonth;
  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final double totalCost;
  final int count;
  final double? costPerKwh;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: palette.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isCurrentMonth ? '$monthLabel · 本月' : monthLabel,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _NavArrow(
                  icon: Icons.chevron_left_rounded,
                  enabled: canGoPrev,
                  onTap: onPrev,
                ),
                const SizedBox(width: 4),
                _NavArrow(
                  icon: Icons.chevron_right_rounded,
                  enabled: canGoNext,
                  onTap: onNext,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCol(
                    label: '费用',
                    value: '¥${formatYuan(totalCost)}',
                  ),
                ),
                _statDivider(palette.divider),
                Expanded(
                  child: _StatCol(label: '次数', value: '$count', unit: '次'),
                ),
                _statDivider(palette.divider),
                Expanded(
                  child: _StatCol(
                    label: '度电成本',
                    value: costPerKwh == null ? '--' : formatYuan(costPerKwh!),
                    unit: costPerKwh == null ? null : '¥/kWh',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statDivider(Color color) => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: color,
  );
}

class _StatCol extends StatelessWidget {
  const _StatCol({required this.label, required this.value, this.unit});

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: palette.textHint)),
        const SizedBox(height: 4),
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: palette.onSurface,
                ),
              ),
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(fontSize: 10, color: palette.textHint),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 22,
          color: enabled
              ? context.palette.onSurfaceVariant
              : context.palette.divider,
        ),
      ),
    );
  }
}

/// 充电年度报告入口卡。
class _ReportEntryCard extends StatelessWidget {
  const _ReportEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.primaryContainer,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
                child: Icon(
                  Icons.insights_rounded,
                  size: 20,
                  color: palette.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '充电年度报告',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '回顾这一年的充电足迹与花费',
                      style: TextStyle(fontSize: 12, color: palette.textHint),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: palette.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 筛选 chip（选中态次级容器底色 + 主色描边，与支出页同款）。
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? palette.secondaryContainer : palette.inputBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? palette.primaryContainer : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected
                ? palette.onSecondaryContainer
                : palette.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
