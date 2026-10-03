import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/domain/maintenance_costs.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';

import 'cost_card.dart' show expenseTypeIcon;

/// 养车支出详情弹层（样式对齐小程序 CostDetailSheet：
/// 居中头部类型色图标/金额/类型 chip + 右对齐行式信息 + 软按钮操作区）。
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
          const SizedBox(height: 8),
          // 头部：类型色图标 → 金额 → 类型 chip（居中纵向）
          Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: typeColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  expenseTypeIcon(expense.type),
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '¥${formatYuan(expense.amount)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: palette.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: palette.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppColors.radiusXl),
                ),
                child: Text(
                  meta.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 行式信息：label 左 / value 右对齐，末行（备注）无分割线
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
            isLast: true,
          ),
          const SizedBox(height: 24),
          // 操作区：中性编辑 + 危险删除软按钮（等宽）
          Row(
            children: [
              Expanded(
                child: _SheetAction(
                  icon: Icons.edit_outlined,
                  label: '编辑这条支出',
                  iconColor: palette.textSecondary,
                  textColor: palette.onSurface,
                  background: palette.surfaceContainerLow,
                  onTap: () {
                    Navigator.of(context).pop();
                    onEdit();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SheetAction(
                  icon: Icons.delete_outline_rounded,
                  label: '删除这条支出',
                  iconColor: palette.error,
                  textColor: palette.onErrorContainer,
                  background: palette.errorContainer,
                  onTap: () {
                    Navigator.of(context).pop();
                    onDelete();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: palette.divider, width: 0.5),
              ),
            ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: palette.textSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                color: palette.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 操作软按钮：圆角底色 + 居中图标/文字（对齐小程序 cd-detail-edit/delete）。
class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.textColor,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
