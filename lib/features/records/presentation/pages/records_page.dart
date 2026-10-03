import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/inspection_memo_calc.dart'
    show statusOverdue;
import 'package:ev_tool_app/core/domain/memo_reminder.dart';
import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/domain/user_badges.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/routing/route_names.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/empty_state.dart';
import 'package:ev_tool_app/core/widgets/gradient_hero_card.dart';
import 'package:ev_tool_app/core/widgets/main_shell.dart';
import 'package:ev_tool_app/core/widgets/undo_bar.dart';
import 'package:ev_tool_app/features/records/presentation/providers/records_provider.dart';
import 'package:ev_tool_app/features/records/presentation/widgets/record_card.dart';
import 'package:ev_tool_app/features/records/presentation/widgets/record_detail_sheet.dart';

/// 「最近记录」展示条数上限，完整列表在充电统计页查看。
const int _recentLimit = 3;

/// 充电记录页（Tab 0，启动页）。
class RecordsPage extends ConsumerStatefulWidget {
  const RecordsPage({super.key});

  @override
  ConsumerState<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends ConsumerState<RecordsPage> {
  List<ChargeRecord> _deletedPending = [];
  bool _undoFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 从新增/统计/车辆页返回时刷新列表与车辆（保存 → 返回 → 重新汇总闭环）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(recordsProvider.notifier).reload();
        ref.read(vehiclesProvider.notifier).reload();
      }
    });
  }

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
        title: const Text('Delete Record'),
        content: const Text(
          'You can undo from the bar at the bottom for 5 seconds. Delete this record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.palette.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
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
      text: _undoFailed
          ? 'Restore failed — tap to retry'
          : 'Deleted ${_deletedPending.length} '
                '${_deletedPending.length == 1 ? 'record' : 'records'}',
      actionText: _undoFailed ? 'Retry' : 'Undo',
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
        ..showSnackBar(const SnackBar(content: Text('Restored')));
      _deletedPending = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(recordsProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final memoReminder = ref.watch(memoReminderProvider);
    final monthKey = getCurrentMonthKey();
    final summary = calcMonthSummary(records, monthKey);
    final prevSummary = calcMonthSummary(records, shiftMonthKey(monthKey, -1));
    final showMonthCompare = prevSummary.count > 0 && summary.count > 0;
    final monthDiff = summary.totalCost - prevSummary.totalCost;
    final monthLabel = formatMonthLabel(monthKey);
    final badgeProgress = buildBadgeProgress(records.length);

    final recent = records.take(_recentLimit).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Charging Records')),
      body: ListView(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: kBottomNavScrollPadding,
        ),
        children: [
          if (memoReminder != null) ...[
            _MemoReminderBar(reminder: memoReminder),
            const SizedBox(height: 12),
          ],
          if (records.isNotEmpty) ...[
            GradientHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$monthLabel · This Month',
                          // hero-label--strong：纯白 14px（对齐小程序）
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      HeroCircleButton(
                        icon: Icons.add_rounded,
                        onTap: () => context.push(RouteNames.recordAdd),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  HeroValue(value: formatYuan(summary.totalCost), unit: '\$'),
                  const SizedBox(height: 20),
                  HeroStatsRow(
                    items: [
                      HeroStatItem(label: 'Charges', value: '${summary.count}'),
                      HeroStatItem(
                        label: 'Energy',
                        value: formatYuan(summary.totalEnergy),
                        unit: 'kWh',
                      ),
                      HeroStatItem(
                        label: 'Avg Cost',
                        value: summary.costPerKwh == null
                            ? '--'
                            : formatYuan(summary.costPerKwh!),
                        unit: '\$/kWh',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (showMonthCompare) ...[
            _HintBar(
              icon: Icons.compare_arrows_rounded,
              text:
                  'Last month: ${prevSummary.count} charges · \$'
                  '${formatYuan(prevSummary.totalCost)} · this month '
                  '${monthDiff >= 0 ? 'spent \$${formatYuan(monthDiff)} more' : 'spent \$${formatYuan(-monthDiff)} less'}',
            ),
            const SizedBox(height: 8),
          ],
          if (badgeProgress != null) ...[
            _HintBar(
              icon: Icons.star_rounded,
              text:
                  'Log ${badgeProgress.remaining} more charges to reach '
                  '"${badgeProgress.nextLabel}"',
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Recent · ${recent.length}',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (records.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      'Long-press to delete',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.palette.textHint,
                      ),
                    ),
                  ],
                ],
              ),
              if (records.length > _recentLimit)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push(RouteNames.chargeStats),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.palette.textHint,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: context.palette.textHint,
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
              icon: Icons.ev_station_rounded,
              title: 'No records yet',
              subtitle:
                  'Add your first charging record to start tracking costs',
              ctaText: 'Add Record',
              onCta: () => context.push(RouteNames.recordAdd),
            )
          else
            for (final record in recent)
              RecordCard(
                record: record,
                vehicles: vehicles,
                onOpen: (id) {
                  final target = records.where((r) => r.id == id).firstOrNull;
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

class _MemoReminderBar extends StatelessWidget {
  const _MemoReminderBar({required this.reminder});

  final MemoReminder reminder;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isOverdue = reminder.level == statusOverdue;
    final color = isOverdue ? palette.error : palette.primary;

    return Material(
      color: isOverdue ? palette.errorContainer : palette.secondaryContainer,
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        onTap: () => context.push(RouteNames.inspectionMemo),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reminder.text,
                  style: TextStyle(fontSize: 13, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: palette.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HintBar extends StatelessWidget {
  const _HintBar({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Icon(icon, size: 14, color: palette.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
