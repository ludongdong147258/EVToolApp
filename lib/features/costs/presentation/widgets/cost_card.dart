import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/domain/charge_records.dart'
    show formatRecordDate;
import 'package:ev_tool_app/core/domain/maintenance_costs.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';

/// 支出类型图标（领域层 icon 名 → Material IconData）。
IconData expenseTypeIcon(String type) => switch (type) {
  'insurance' => Icons.verified_user_outlined,
  'parking' => Icons.place_rounded,
  'wash' => Icons.water_drop_outlined,
  'maintenance' => Icons.build_rounded,
  'toll' => Icons.speed_rounded,
  'fine' => Icons.warning_amber_rounded,
  'parts' => Icons.settings_rounded,
  _ => Icons.payments_rounded,
};

/// 养车支出卡片（移植小程序 CostCard）。
///
/// 点按打开详情，长按删除，「⋯」弹出操作菜单（编辑/删除）。
class CostCard extends StatelessWidget {
  const CostCard({
    super.key,
    required this.expense,
    this.onOpen,
    this.onEdit,
    this.onDelete,
  });

  final Expense expense;

  /// 点按 → 详情弹层。
  final ValueChanged<String>? onOpen;

  /// 编辑回调。
  final ValueChanged<String>? onEdit;

  /// 删除回调（页面弹确认）。
  final ValueChanged<String>? onDelete;

  ExpenseTypeMeta get _meta =>
      EXPENSE_TYPE_META[expense.type] ?? EXPENSE_TYPE_META['other']!;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final typeColor = AppColors.costTypeColor(expense.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        onTap: onOpen == null ? null : () => onOpen!(expense.id),
        onLongPress: onDelete == null ? null : () => onDelete!(expense.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              expenseTypeIcon(expense.type),
                              size: 14,
                              color: typeColor,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _meta.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatRecordDate(expense.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '-${formatMoney(expense.amount)}',
                    style: context.textTheme.titleMedium?.copyWith(
                      color: palette.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (onEdit != null || onDelete != null) ...[
                    const SizedBox(width: 4),
                    _MoreButton(
                      onEdit: onEdit == null ? null : () => onEdit!(expense.id),
                      onDelete: onDelete == null
                          ? null
                          : () => onDelete!(expense.id),
                    ),
                  ],
                ],
              ),
              if (expense.note.isNotEmpty ||
                  (expense.vehicleName ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                if (expense.note.isNotEmpty)
                  Text(
                    expense.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                if ((expense.vehicleName ?? '').isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.directions_car_rounded,
                        size: 13,
                        color: palette.textHint,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          expense.vehicleName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textHint,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({this.onEdit, this.onDelete});

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 18,
        color: context.palette.textHint,
      ),
      onPressed: () => _showMenu(context),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onEdit?.call();
                },
              ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: context.palette.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: context.palette.error),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}
