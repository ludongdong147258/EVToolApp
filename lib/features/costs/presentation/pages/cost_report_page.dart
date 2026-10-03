import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ev_tool_app/core/domain/annual_report.dart'
    show calcBarPercents, getAvailableYears;
import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/core/domain/maintenance_costs.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/routing/route_names.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart';
import 'package:ev_tool_app/core/widgets/empty_state.dart';
import 'package:ev_tool_app/core/widgets/gradient_hero_card.dart';
import 'package:ev_tool_app/core/widgets/month_bar_chart.dart';
import 'package:ev_tool_app/core/widgets/stacked_bar.dart';
import 'package:ev_tool_app/features/costs/presentation/providers/costs_provider.dart';
import 'package:ev_tool_app/features/records/presentation/providers/records_provider.dart';

/// 周期筛选（报表按月度或年度聚合）。
const List<(String, String)> _modeFilters = <(String, String)>[
  ('month', '月度'),
  ('year', '年度'),
];

/// 充电 + 养车两类账单的可用月份并集（降序去重），供月度切换确定边界。
List<String> availablePeriodMonths(
  List<ChargeRecord> records,
  List<Expense> expenses,
) {
  final months = <String>{...getAvailableMonths(records)};
  for (final expense in expenses) {
    final monthKey = getMonthKey(expense.date);
    if (monthKey != null) months.add(monthKey);
  }
  final sorted = months.toList()..sort();
  return sorted.reversed.toList();
}

/// 充电 + 养车两类账单的可用年份并集（降序去重），供年度切换确定边界。
List<int> availablePeriodYears(
  List<ChargeRecord> records,
  List<Expense> expenses,
) {
  final years = <int>{...getAvailableYears(records)};
  for (final expense in expenses) {
    final monthKey = getMonthKey(expense.date);
    final year = monthKey == null
        ? null
        : int.tryParse(monthKey.substring(0, 4));
    if (year != null) years.add(year);
  }
  final sorted = years.toList()..sort((a, b) => b.compareTo(a));
  return sorted;
}

/// 综合费用统计报表页（子页，从养车支出 Tab 进入）：
/// 充电账单 + 养车支出合并汇总、分项占比与文字小结。
class CostReportPage extends ConsumerStatefulWidget {
  const CostReportPage({super.key});

  @override
  ConsumerState<CostReportPage> createState() => _CostReportPageState();
}

class _CostReportPageState extends ConsumerState<CostReportPage> {
  String _mode = 'month';
  String _monthKey = getCurrentMonthKey();
  int _year = DateTime.now().year;
  String? _vehicleFilter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 从记录/支出/车辆页返回时刷新（新增、删除、改名后数据保持同步）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(recordsProvider.notifier).reload();
        ref.read(costsProvider.notifier).reload();
        ref.read(vehiclesProvider.notifier).reload();
      }
    });
  }

  /* ---------- 周期切换（越界方向直接忽略） ---------- */

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

  void _goPrevYear(List<int> availableYears) {
    final oldest = availableYears.isEmpty ? null : availableYears.last;
    if (oldest == null || _year - 1 < oldest) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _year = _year - 1);
  }

  void _goNextYear() {
    if (_year + 1 > DateTime.now().year) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _year = _year + 1);
  }

  /* ---------- 图例点击 → 支出台账并应用类型筛选 ---------- */

  void _onLegendTap(String key) {
    unawaited(HapticFeedback.lightImpact());
    ref.read(costFilterIntentProvider.notifier).state = key;
    context.go(RouteNames.costs);
  }

  /// 复制当前周期文字小结（可直接粘贴到车友群）。
  Future<void> _copySummary(
    List<TypeBreakdownItem> breakdown,
    double total,
    String periodLabel,
  ) async {
    try {
      await Clipboard.setData(
        ClipboardData(
          text: buildReportTextLine(breakdown, total, periodLabel: periodLabel),
        ),
      );
      if (mounted) showAppToast(context, '小结已复制');
    } on Exception catch (err) {
      appLogger.e('复制小结失败', error: err);
      if (mounted) showAppToast(context, '复制失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final records = ref.watch(recordsProvider);
    final expenses = ref.watch(costsProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final currentMonthKey = getCurrentMonthKey();
    final currentYear = DateTime.now().year;

    /* 两类账单均无数据 → 整页空态（同年度报告页模式） */
    if (records.isEmpty && expenses.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('综合费用统计')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            EmptyState(
              icon: Icons.bar_chart_rounded,
              title: '暂无账单数据',
              subtitle: '记一笔充电或养车支出后，这里将展示综合统计',
              ctaText: '去记一笔',
              onCta: () => context.go(RouteNames.records),
            ),
          ],
        ),
      );
    }

    /* 月份/年份切换边界：两类账单数据范围的并集 */
    final availableMonths = availablePeriodMonths(records, expenses);
    final oldestMonth = availableMonths.isEmpty ? null : availableMonths.last;
    final canGoPrevMonth =
        oldestMonth != null && _monthKey.compareTo(oldestMonth) > 0;
    final canGoNextMonth = _monthKey.compareTo(currentMonthKey) < 0;
    final availableYears = availablePeriodYears(records, expenses);
    final oldestYear = availableYears.isEmpty ? null : availableYears.last;
    final canGoPrevYear = oldestYear != null && _year > oldestYear;
    final canGoNextYear = _year < currentYear;

    /* 按周期/车辆分别过滤两类账单后合并汇总 */
    final isMonthMode = _mode == 'month';
    final chargeRecords = filterRecords(
      records,
      RecordFilters(
        monthKey: isMonthMode ? _monthKey : null,
        year: isMonthMode ? null : _year.toString(),
        vehicleId: _vehicleFilter,
      ),
    );
    final periodExpenses = filterExpenses(
      expenses,
      ExpenseFilters(
        monthKey: isMonthMode ? _monthKey : null,
        year: isMonthMode ? null : _year.toString(),
        vehicleId: _vehicleFilter,
      ),
    );
    final summary = calcCombinedSummary(chargeRecords, periodExpenses);
    final breakdown = sortTypeBreakdown(summary);
    final expensePercent = summary.total > 0
        ? ((summary.expenseTotal / summary.total) * 100).round()
        : 0;
    final monthLabel = formatMonthLabel(_monthKey);
    final periodLabel = isMonthMode ? monthLabel : '$_year年度';

    /* 年度模式：月度趋势柱状图数据（充电 + 养车按月合并） */
    final monthlyTotals = isMonthMode
        ? null
        : calcCombinedMonthlyTotals(chargeRecords, periodExpenses, _year);

    return Scaffold(
      appBar: AppBar(title: const Text('综合费用统计')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 周期概览卡
          GradientHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$periodLabel · 用车总花费',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.onPrimaryA85,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                HeroValue(value: formatYuan(summary.total), unit: '¥'),
                const SizedBox(height: 16),
                HeroStatsRow(
                  items: [
                    HeroStatItem(
                      label: '充电',
                      value: formatYuan(summary.chargeTotal),
                      unit: '元',
                    ),
                    HeroStatItem(
                      label: '养车支出',
                      value: formatYuan(summary.expenseTotal),
                      unit: '元',
                    ),
                    HeroStatItem(
                      label: '养车占比',
                      value: summary.total > 0 ? '$expensePercent%' : '--',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 周期 + 车辆筛选
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in _modeFilters)
                _FilterChip(
                  label: label,
                  isSelected: _mode == value,
                  onTap: () => setState(() => _mode = value),
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

          // 月份/年份切换（浅色卡，越界置灰）
          _PeriodCard(
            label: isMonthMode
                ? (_monthKey == currentMonthKey
                      ? '$monthLabel · 本月'
                      : monthLabel)
                : (_year == currentYear ? '$_year年 · 今年' : '$_year年'),
            canGoPrev: isMonthMode ? canGoPrevMonth : canGoPrevYear,
            canGoNext: isMonthMode ? canGoNextMonth : canGoNextYear,
            onPrev: isMonthMode
                ? () => _goPrevMonth(availableMonths)
                : () => _goPrevYear(availableYears),
            onNext: isMonthMode ? _goNextMonth : _goNextYear,
          ),
          const SizedBox(height: 12),

          if (summary.total == 0)
            EmptyState(
              icon: Icons.bar_chart_rounded,
              title: '该周期暂无支出',
              subtitle: '记一笔充电或养车支出后，这里将展示综合统计',
              ctaText: '去记一笔',
              onCta: () => context.go(RouteNames.records),
            )
          else ...[
            // 月度趋势柱状图（仅年度模式）
            if (monthlyTotals != null) _TrendCard(monthlyTotals: monthlyTotals),

            // 分项占比卡：堆叠占比条 + 图例 + 小结
            Card(
              margin: const EdgeInsets.only(top: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.bar_chart_rounded,
                          size: 16,
                          color: palette.primaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '分项占比',
                            style: context.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '按金额',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textHint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    StackedBar(
                      height: 10,
                      segments: [
                        for (final item in breakdown)
                          if (item.totalAmount > 0)
                            StackedSegment(
                              colorKey: item.key,
                              percent: item.percent,
                            ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final item in breakdown)
                      _LegendRow(item: item, onTap: _onLegendTap),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.insights_rounded,
                            size: 14,
                            color: palette.primaryContainer,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            buildReportTextLine(
                              breakdown,
                              summary.total,
                              periodLabel: periodLabel,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => unawaited(
                            _copySummary(breakdown, summary.total, periodLabel),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.content_copy_rounded,
                                  size: 14,
                                  color: palette.textHint,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '复制',
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
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 年度模式月度趋势卡（12 柱，充电 + 养车合并）。
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.monthlyTotals});

  final List<MonthlyTotal> monthlyTotals;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    /* MonthlyTotal 形状兼容 calcBarPercents（只读 totalCost） */
    final percents = calcBarPercents([
      for (final month in monthlyTotals)
        MonthSummary(
          monthKey: month.monthKey,
          count: month.count,
          totalCost: month.totalCost,
          totalEnergy: 0,
          costPerKwh: null,
        ),
    ]);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  size: 16,
                  color: palette.primaryContainer,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '月度趋势',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '单位：元',
                  style: TextStyle(fontSize: 12, color: palette.textHint),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MonthBarChart(
              bars: [
                for (var i = 0; i < monthlyTotals.length; i++)
                  MonthBar(
                    month: i + 1,
                    percent: percents[i],
                    hasData: monthlyTotals[i].count > 0,
                    valueLabel: monthlyTotals[i].count > 0
                        ? formatAmount(monthlyTotals[i].totalCost)
                        : '',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 月份/年份切换卡（越界箭头置灰）。
class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.label,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: palette.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
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
      ),
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

/// 分项图例行：色点 + 名称 + 笔数·金额·占比；
/// 点击非充电分项跳支出台账并应用该类型筛选。
class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.item, required this.onTap});

  final TypeBreakdownItem item;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isCharge = item.key == chargeTypeKey;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: isCharge ? null : () => onTap(item.key),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.costTypeColor(item.key),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(item.label, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${item.count}笔 · ¥${formatYuan(item.totalAmount)} · ${item.percent}%'
                '${isCharge ? ' · 明细见充电记录' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 12, color: palette.textSecondary),
              ),
            ),
            if (!isCharge)
              Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: palette.textHint,
              ),
          ],
        ),
      ),
    );
  }
}

/// 筛选 chip（chip--sm 小号胶囊，与充电统计/支出页同款）。
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
    // chip--sm：小号胶囊（对齐小程序 padding 10/4 + 全圆角 + 12px 文字，与充电统计同款）
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? palette.secondaryContainer : palette.inputBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? palette.primaryContainer : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
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
