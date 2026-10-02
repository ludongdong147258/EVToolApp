import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ev_tool_app/core/domain/maintenance_costs.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/routing/route_names.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart' show AppColors;
import 'package:ev_tool_app/core/widgets/empty_state.dart';
import 'package:ev_tool_app/core/widgets/gradient_hero_card.dart';
import 'package:ev_tool_app/core/widgets/main_shell.dart'
    show kBottomNavScrollPadding;
import 'package:ev_tool_app/core/widgets/undo_bar.dart';
import 'package:ev_tool_app/features/costs/presentation/providers/costs_provider.dart';
import 'package:ev_tool_app/features/costs/presentation/widgets/cost_card.dart';
import 'package:ev_tool_app/features/costs/presentation/widgets/cost_detail_sheet.dart';
import 'package:ev_tool_app/features/records/presentation/providers/records_provider.dart'
    show vehiclesProvider;

/// 养车支出页（Tab 1）：周期/类型/车辆筛选 + 支出台账列表。
///
/// 移植小程序 cost-list 页；分批渲染简化为全量 ListView（数据量级
/// 为本地台账，性能可接受，行为其余一致）。
class CostListPage extends ConsumerStatefulWidget {
  const CostListPage({super.key});

  @override
  ConsumerState<CostListPage> createState() => _CostListPageState();
}

class _CostListPageState extends ConsumerState<CostListPage> {
  List<Expense> _deletedPending = [];
  bool _undoFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 从新增/编辑/车辆页返回时刷新（保存、删除、改名后数据保持同步）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(costsProvider.notifier).reload();
      ref.read(vehiclesProvider.notifier).reload();
      // 报表图例点击带来的筛选意图（Tab 页无法带 URL 参数，取后即清）
      final intent = ref.read(costFilterIntentProvider);
      if (intent != null) {
        ref.read(costFilterIntentProvider.notifier).state = null;
        ref.read(costFiltersProvider.notifier).setType(intent);
      }
    });
  }

  Future<void> _openDetail(Expense expense) async {
    await showCostDetailSheet(
      context,
      expense: expense,
      onEdit: () => context.push('${RouteNames.costAdd}?id=${expense.id}'),
      onDelete: () => _confirmDelete(expense.id),
    );
  }

  Future<void> _confirmDelete(String id) async {
    unawaited(HapticFeedback.lightImpact());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除支出'),
        content: const Text('删除后 5 秒内可在底部提示条撤销，确定删除这笔支出吗？'),
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
    await _removeExpense(id);
  }

  Future<void> _removeExpense(String id) async {
    final deleted = await ref.read(costsProvider.notifier).remove(id);
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
      text: _undoFailed ? '恢复失败，点此重试' : '已删除 ${_deletedPending.length} 笔支出',
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
    final allOk = await ref.read(costsProvider.notifier).restoreAll(pending);
    if (!mounted) return;
    setState(() => _undoFailed = !allOk);
    if (allOk) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('已恢复')));
      _deletedPending = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final expenses = ref.watch(costsProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final filters = ref.watch(costFiltersProvider);
    final filtered = ref.watch(filteredExpensesProvider);
    final summaryView = ref.watch(expenseSummaryProvider);
    final timeLabel = timeRangeLabels[filters.timePreset] ?? '全部';
    final top = summaryView.top;
    final isEmptyAll = expenses.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('养车支出')),
      body: ListView(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 4,
          bottom: kBottomNavScrollPadding,
        ),
        children: [
          if (isEmptyAll)
            EmptyState(
              icon: Icons.payments_rounded,
              title: '暂无养车支出',
              subtitle: '记录停车、保险、洗车等花费，看清全年养车成本',
              ctaText: '记一笔支出',
              onCta: () => context.push(RouteNames.costAdd),
            )
          else ...[
            // 周期汇总卡（从未记录过支出时整块隐藏，空态降噪）
            GradientHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$timeLabel · 养车支出',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.onPrimaryA85,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      HeroCircleButton(
                        icon: Icons.add_rounded,
                        onTap: () => context.push(RouteNames.costAdd),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  HeroValue(
                    value: formatYuan(summaryView.summary.totalAmount),
                    unit: '¥',
                  ),
                  const SizedBox(height: 16),
                  HeroStatsRow(
                    items: [
                      HeroStatItem(
                        label: '支出笔数',
                        value: '${summaryView.summary.count}',
                        unit: '笔',
                      ),
                      HeroStatItem(
                        label: top == null ? '最高单笔' : '最高单笔·${top.typeLabel}',
                        value: top == null ? '--' : formatYuan(top.amount),
                        unit: top == null ? null : '元',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 综合费用统计入口（充电 + 养车合并报表）
            _ReportEntryCard(onTap: () => context.push(RouteNames.costReport)),
            const SizedBox(height: 12),
            // 时间筛选（4 项单行可容）
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in timeRangePresets)
                  _FilterChip(
                    label: timeRangeLabels[preset] ?? preset,
                    isSelected: filters.timePreset == preset,
                    onTap: () => ref
                        .read(costFiltersProvider.notifier)
                        .setTimePreset(preset),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 类型 + 车辆筛选（单行横滚，压缩首屏高度；高度对齐 chip--sm 胶囊）
            SizedBox(
              height: 28,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: '全部',
                    isSelected: filters.type == null,
                    onTap: () =>
                        ref.read(costFiltersProvider.notifier).setType(null),
                  ),
                  const SizedBox(width: 8),
                  for (final type in expenseTypes) ...[
                    _FilterChip(
                      label: EXPENSE_TYPE_META[type]?.label ?? type,
                      isSelected: filters.type == type,
                      onTap: () =>
                          ref.read(costFiltersProvider.notifier).setType(type),
                    ),
                    const SizedBox(width: 8),
                  ],
                  for (final vehicle in vehicles)
                    _FilterChip(
                      label: vehicle.name,
                      isSelected: filters.vehicleId == vehicle.id,
                      onTap: () => ref
                          .read(costFiltersProvider.notifier)
                          .toggleVehicle(vehicle.id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$timeLabel · ${filtered.length} 条',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '长按可删除',
                  style: TextStyle(fontSize: 12, color: palette.textHint),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () =>
                      ref.read(costFiltersProvider.notifier).toggleSort(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          filters.sortBy == 'amount'
                              ? Icons.trending_up_rounded
                              : Icons.history_rounded,
                          size: 14,
                          color: palette.textHint,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          filters.sortBy == 'amount' ? '金额最高' : '最新',
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
            if (filtered.isEmpty)
              EmptyState(
                compact: true,
                icon: Icons.filter_alt_off_outlined,
                title: '当前筛选条件下暂无支出',
                ctaText: '清除筛选',
                onCta: () => ref.read(costFiltersProvider.notifier).clearAll(),
              )
            else
              for (final expense in filtered)
                CostCard(
                  expense: expense,
                  onOpen: (id) {
                    final target = filtered
                        .where((item) => item.id == id)
                        .firstOrNull;
                    if (target != null) _openDetail(target);
                  },
                  onEdit: (id) => context.push('${RouteNames.costAdd}?id=$id'),
                  onDelete: _confirmDelete,
                ),
          ],
        ],
      ),
    );
  }
}

/// 筛选 chip（选中态次级容器底色 + 主色描边）。
/// 综合费用统计入口卡（对应小程序 cost-list 页的入口卡）。
class _ReportEntryCard extends StatelessWidget {
  const _ReportEntryCard({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.secondaryContainer,
                  shape: BoxShape.circle,
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
                      '综合费用统计',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '充电 + 养车支出合并报表',
                      style: TextStyle(fontSize: 12, color: palette.textHint),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: palette.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
