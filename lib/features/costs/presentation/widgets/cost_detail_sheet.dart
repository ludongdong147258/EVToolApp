import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/domain/maintenance_costs.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';

import 'cost_card.dart' show expenseTypeIcon;

/// 养车支出详情弹层（移植小程序 CostDetailSheet）。
///
/// 头部：类型色图标 + 金额 + 类型标签；行式信息 + 编辑/删除操作。
Future<void> showCostDetailSheet(
  BuildContext context, {
  required Expense expense,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  final palette = context.palette;
  final meta = EXPENSE_TYPE_META[expense.type] ?? EXPENSE_TYPE_META['other']!;
  final typeColor = AppColors.costTypeColor(expense.type);

  return showAppSheet(
    context: context,
    title: '支出详情',
    builder: (context) => AppSheetScrollBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: typeColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  expenseTypeIcon(expense.type),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¥${formatYuan(expense.amount)}',
                      style: context.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                      child: Text(
                        meta.label,
                        style: TextStyle(fontSize: 12, color: typeColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SheetRow(label: '支出日期', value: formatDateCn(expense.date)),
          _SheetRow(
            label: '车辆',
            value: (expense.vehicleName ?? '').isNotEmpty
                ? expense.vehicleName!
                : '未关联',
          ),
          _SheetRow(
            label: '备注',
            value: expense.note.isEmpty ? '—' : expense.note,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onEdit();
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('编辑这条支出'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.error,
              minimumSize: const Size.fromHeight(50),
              side: BorderSide(color: palette.errorContainer),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              onDelete();
            },
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: palette.error,
            ),
            label: const Text('删除这条支出'),
          ),
        ],
      ),
    ),
  );
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.divider, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: palette.textHint),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: palette.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
