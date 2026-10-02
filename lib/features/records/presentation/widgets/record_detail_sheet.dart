import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';

/// 充电记录详情弹层（样式对齐小程序 RecordDetailSheet：
/// 居中头部图标/金额/类型 chip + 右对齐行式信息 + 软按钮操作区）。
Future<void> showRecordDetailSheet(
  BuildContext context, {
  required ChargeRecord record,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  final palette = context.palette;
  final isHome = record.type == 'home';
  final costPerKwh = calcCostPerKwh(record.cost, record.energy);
  final avgPower = record.durationMinutes != null && record.durationMinutes! > 0
      ? record.energy / (record.durationMinutes! / 60)
      : null;
  final durationFormatted = formatDuration(record.durationMinutes);
  final durationText = durationFormatted.isEmpty ? '未记录' : durationFormatted;

  return showAppSheet(
    context: context,
    title: '记录详情',
    builder: (context) => AppSheetScrollBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // 头部：类型图标 → 金额 → 类型 chip（居中纵向）
          Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isHome ? palette.secondary : palette.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isHome ? Icons.home_rounded : Icons.bolt_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '¥${formatYuan(record.cost)}',
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
                  typeDefaultTitles[record.type] ?? record.type,
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
          _SheetRow(label: '充电日期', value: formatRecordDate(record.date)),
          if (record.vehicleName?.isNotEmpty == true)
            _SheetRow(label: '车辆', value: record.vehicleName!),
          _SheetRow(label: '充电电量', value: '${formatYuan(record.energy)} kWh'),
          _SheetRow(
            label: '度电单价',
            value: costPerKwh == null ? '--' : '¥${formatYuan(costPerKwh)}/kWh',
          ),
          _SheetRow(label: '充电时长', value: durationText),
          _SheetRow(
            label: '平均功率',
            value: avgPower == null ? '—' : '${formatYuan(avgPower)} kW',
          ),
          if (record.locationName?.isNotEmpty == true)
            _SheetRow(
              label: '地点',
              value: [
                record.city,
                record.locationName,
              ].whereType<String>().join(' · '),
            ),
          _SheetRow(
            label: '备注',
            value: record.note.isNotEmpty ? record.note : '—',
            isLast: true,
          ),
          const SizedBox(height: 24),
          // 操作区：中性编辑 + 危险删除软按钮（等宽）
          Row(
            children: [
              Expanded(
                child: _SheetAction(
                  icon: Icons.edit_outlined,
                  label: '编辑这条记录',
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
                  label: '删除这条记录',
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

/// 操作软按钮：圆角底色 + 居中图标/文字（对齐小程序 rc-detail-edit/delete）。
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
