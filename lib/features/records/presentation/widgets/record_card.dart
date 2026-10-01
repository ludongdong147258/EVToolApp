import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/domain/vehicles.dart';
import 'package:ev_tool_app/features/vehicles/presentation/widgets/vehicle_avatar.dart';

/// 充电记录卡片（移植小程序 RecordCard）。
///
/// 点按打开详情，长按删除，「⋯」弹出操作菜单（编辑/删除）。
class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.record,
    required this.vehicles,
    this.onOpen,
    this.onEdit,
    this.onDelete,
  });

  final ChargeRecord record;
  final List<Vehicle> vehicles;

  /// 点按 → 详情弹层。
  final ValueChanged<String>? onOpen;

  /// 编辑回调。
  final ValueChanged<String>? onEdit;

  /// 删除回调（弹确认）。
  final ValueChanged<String>? onDelete;

  bool get _isHome => record.type == 'home';

  Vehicle? get _vehicle {
    for (final vehicle in vehicles) {
      if (vehicle.id == record.vehicleId) return vehicle;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final typeLabel = typeDefaultTitles[record.type] ?? record.type;
    final costPerKwh = calcCostPerKwh(record.cost, record.energy);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        onTap: onOpen == null ? null : () => onOpen!(record.id),
        onLongPress: onDelete == null ? null : () => onDelete!(record.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _isHome
                          ? palette.secondaryContainer
                          : palette.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isHome ? Icons.home_rounded : Icons.bolt_rounded,
                      size: 20,
                      color: _isHome
                          ? palette.onSecondaryContainer
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeLabel,
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatRecordDate(record.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '¥${formatYuan(record.cost)}',
                    style: context.textTheme.titleMedium?.copyWith(
                      color: palette.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (onEdit != null || onDelete != null) ...[
                    const SizedBox(width: 4),
                    _MoreButton(
                      onEdit: onEdit == null ? null : () => onEdit!(record.id),
                      onDelete: onDelete == null
                          ? null
                          : () => onDelete!(record.id),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _MetaChip(
                    icon: Icons.battery_charging_full_rounded,
                    label: '${formatYuan(record.energy)} kWh',
                  ),
                  const SizedBox(width: 8),
                  _MetaChip(
                    icon: Icons.payments_rounded,
                    label: costPerKwh == null
                        ? '-- 元/度'
                        : '${formatYuan(costPerKwh)} 元/度',
                  ),
                  const Spacer(),
                  if (_vehicle != null)
                    Row(
                      children: [
                        VehicleAvatar(vehicle: _vehicle!, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          _vehicle!.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    )
                  else if ((record.vehicleName ?? '').isNotEmpty)
                    Text(
                      record.vehicleName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: palette.textSecondary),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: palette.textSecondary),
          ),
        ],
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
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑记录'),
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
                '删除记录',
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
