import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/domain/vehicles.dart';
import 'package:ev_tool_app/features/vehicles/presentation/widgets/vehicle_avatar.dart';

/// 充电记录卡片（样式对齐小程序 RecordCard：
/// 实心类型圆标 + 备注标题 + `-¥` 支出金额 + 无底色 meta 行）。
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 标题：备注优先，回落类型名（对齐小程序 record-title）
    final title = record.note.isNotEmpty
        ? record.note
        : typeDefaultTitles[record.type] ?? record.type;
    final costPerKwh = calcCostPerKwh(record.cost, record.energy);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        // --ev-shadow-card-soft：浅色 4% / 深色 30%
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          onTap: onOpen == null ? null : () => onOpen!(record.id),
          onLongPress: onDelete == null ? null : () => onDelete!(record.id),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _isHome ? palette.secondary : palette.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isHome ? Icons.home_rounded : Icons.bolt_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: palette.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatRecordDate(record.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '-¥${formatYuan(record.cost)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: palette.onSurface,
                      ),
                    ),
                    if (onEdit != null || onDelete != null) ...[
                      const SizedBox(width: 4),
                      _MoreButton(
                        onEdit: onEdit == null
                            ? null
                            : () => onEdit!(record.id),
                        onDelete: onDelete == null
                            ? null
                            : () => onDelete!(record.id),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MetaItem(
                      icon: Icons.battery_charging_full_rounded,
                      label: '${formatYuan(record.energy)} kWh',
                    ),
                    _MetaItem(
                      icon: Icons.payments_rounded,
                      label: costPerKwh == null
                          ? '--/度'
                          : '¥${formatYuan(costPerKwh)}/度',
                    ),
                    if (_vehicle != null)
                      _VehicleMeta(vehicle: _vehicle!)
                    else if ((record.vehicleName ?? '').isNotEmpty)
                      _MetaItem(
                        icon: Icons.directions_car_rounded,
                        label: record.vehicleName!,
                        maxTextWidth: 100,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// meta 行纯文本项：icon + 文字（无底色，对齐小程序 record-meta-item）。
class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label, this.maxTextWidth});

  final IconData icon;
  final String label;
  final double? maxTextWidth;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: palette.textSecondary),
        const SizedBox(width: 4),
        if (maxTextWidth != null)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxTextWidth!),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
          )
        else
          Text(
            label,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
      ],
    );
  }
}

/// 车辆 meta：照片小圆（无照片回落图标）+ 车名超长截断。
class _VehicleMeta extends StatelessWidget {
  const _VehicleMeta({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VehicleAvatar(vehicle: vehicle, size: 16),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 100),
          child: Text(
            vehicle.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
        ),
      ],
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
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 16,
        color: context.palette.textSecondary,
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
