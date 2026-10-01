import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';

/// 充电记录详情弹层（移植小程序 RecordDetailSheet）。
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

  return showAppSheet(
    context: context,
    title: '充电详情',
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
                  color: isHome
                      ? palette.secondaryContainer
                      : palette.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isHome ? Icons.home_rounded : Icons.bolt_rounded,
                  color: isHome ? palette.onSecondaryContainer : Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¥${formatYuan(record.cost)}',
                      style: context.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      typeDefaultTitles[record.type] ?? record.type,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SheetRow(label: '日期', value: record.date),
          _SheetRow(
            label: '车辆',
            value: record.vehicleName?.isNotEmpty == true
                ? record.vehicleName!
                : '未关联',
          ),
          _SheetRow(label: '电量', value: '${formatYuan(record.energy)} kWh'),
          _SheetRow(
            label: '度电成本',
            value: costPerKwh == null
                ? '--'
                : '${formatYuan(costPerKwh)} 元/kWh',
          ),
          if (record.durationMinutes != null)
            _SheetRow(
              label: '充电时长',
              value: formatDuration(record.durationMinutes),
            ),
          if (avgPower != null)
            _SheetRow(label: '平均功率', value: '${formatYuan(avgPower)} kW'),
          if (record.locationName?.isNotEmpty == true)
            _SheetRow(
              label: '地点',
              value: [
                record.city,
                record.locationName,
              ].whereType<String>().join(' · '),
            ),
          if (record.note.isNotEmpty)
            _SheetRow(label: '备注', value: record.note),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onEdit();
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('编辑这条记录'),
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
            label: const Text('删除这条记录'),
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
