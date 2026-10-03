import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ev_tool_app/core/domain/vehicles.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/core/widgets/app_primary_button.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart';
import 'package:ev_tool_app/core/widgets/empty_state.dart';
import 'package:ev_tool_app/features/records/presentation/providers/records_provider.dart';
import 'package:ev_tool_app/features/vehicles/data/photo_store.dart';
import 'package:ev_tool_app/features/vehicles/presentation/widgets/vehicle_avatar.dart';

/// 我的车辆（子页）：车辆卡片列表 + 新增/编辑弹层。
///
/// 移植小程序 src/pages/vehicles/index.js：
/// 照片三态（未变 / 新选 / 清空）、脏检查放弃确认、
/// more 菜单收设默认与删除（均为破坏性操作，二次确认）。
class VehiclesPage extends ConsumerWidget {
  const VehiclesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的车辆')),
      body: vehicles.isEmpty
          ? ListView(
              children: [
                EmptyState(
                  icon: Icons.directions_car_rounded,
                  title: '暂无车辆',
                  subtitle: '添加车辆信息，方便后续计算充电花费',
                  ctaText: '添加车辆',
                  onCta: () => _openVehicleSheet(context, ref),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                for (final vehicle in vehicles)
                  _VehicleCard(
                    vehicle: vehicle,
                    onTap: () => _openVehicleSheet(context, ref, vehicle),
                    onMore: () => _showMoreMenu(context, ref, vehicle),
                  ),
                _AddVehicleTile(onTap: () => _openVehicleSheet(context, ref)),
              ],
            ),
    );
  }
}

/// 打开新增/编辑弹层（编辑时草稿以当前车辆初始化）。
Future<void> _openVehicleSheet(
  BuildContext context,
  WidgetRef ref, [
  Vehicle? vehicle,
]) {
  return showAppSheet(
    context: context,
    title: vehicle == null ? '添加车辆' : '编辑车辆',
    builder: (_) => _VehicleFormSheet(vehicle: vehicle),
  );
}

/// 卡片 more 菜单：低频操作（设为默认/删除）收进底部操作面板。
Future<void> _showMoreMenu(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!vehicle.isDefault)
            ListTile(
              leading: const Icon(Icons.star_rounded),
              title: const Text('设为默认'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmSetDefault(context, ref, vehicle);
              },
            ),
          ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: context.palette.error,
            ),
            title: Text('删除', style: TextStyle(color: context.palette.error)),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _confirmRemove(context, ref, vehicle);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _confirmSetDefault(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('设为默认'),
      content: Text('将「${vehicle.name}」设为默认车辆？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('设为默认'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ref.read(vehiclesProvider.notifier).setDefault(vehicle.id);
    if (context.mounted) showAppToast(context, '已设为默认');
  } on Exception {
    if (context.mounted) showAppToast(context, '设置失败，请重试');
  }
}

Future<void> _confirmRemove(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('删除车辆'),
      content: Text('删除后不可恢复，确定删除“${vehicle.name}”吗？'),
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
  if (confirmed != true || !context.mounted) return;

  final photoPath = vehicle.photoPath;
  try {
    // 删除默认车时仓储会把剩余首辆置为默认，并级联清理记录快照
    await ref.read(vehiclesProvider.notifier).remove(vehicle.id);
    if (photoPath.isNotEmpty) {
      final store = await ref.read(photoStoreProvider.future);
      unawaited(store.delete(photoPath));
    }
    if (context.mounted) showAppToast(context, '已删除');
  } on Exception {
    if (context.mounted) showAppToast(context, '删除失败，请重试');
  }
}

/// 单张车辆卡片：头像 + 昵称 + 默认徽标 + 电池容量 + 备注。
class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.onTap,
    required this.onMore,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  VehicleAvatar(vehicle: vehicle, size: 44),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      vehicle.name,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (vehicle.isDefault) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.secondaryContainer,
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: palette.onSecondaryContainer,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '默认',
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: palette.textHint,
                    ),
                    onPressed: onMore,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.battery_charging_full_rounded,
                    size: 16,
                    color: palette.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '电池容量',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatBattery(vehicle.battery),
                    style: TextStyle(
                      fontSize: 14,
                      color: palette.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    ' kWh',
                    style: TextStyle(fontSize: 12, color: palette.textHint),
                  ),
                ],
              ),
              if (vehicle.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  vehicle.note,
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// JS Number.toString()：整数不带小数位。
String _formatBattery(double value) =>
    value == value.roundToDouble() ? value.round().toString() : '$value';

/// 添加车辆入口卡片。
class _AddVehicleTile extends StatelessWidget {
  const _AddVehicleTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 18, color: palette.textSecondary),
              const SizedBox(width: 4),
              Text(
                '添加车辆',
                style: TextStyle(
                  fontSize: 14,
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 新增/编辑表单弹层内容。
///
/// 弹层草稿：昵称 / 容量 / 备注 / 照片（已存裸文件名或新选临时路径），
/// 与打开时的快照逐字段比较做脏检查。
class _VehicleFormSheet extends ConsumerStatefulWidget {
  const _VehicleFormSheet({this.vehicle});

  /// null = 新增模式。
  final Vehicle? vehicle;

  @override
  ConsumerState<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends ConsumerState<_VehicleFormSheet> {
  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.vehicle?.name ?? '',
  );
  late final TextEditingController _batteryCtrl = TextEditingController(
    text: widget.vehicle == null ? '' : _formatBattery(widget.vehicle!.battery),
  );
  late final TextEditingController _noteCtrl = TextEditingController(
    text: widget.vehicle?.note ?? '',
  );

  /// 照片三态：未变（原裸文件名）/ 新选（临时路径）/ 清空（''）。
  late String _photoDraft = widget.vehicle?.photoPath ?? '';

  /// 打开弹层时的草稿快照（脏检查基准）。
  late final _SheetSnapshot _snapshot = _SheetSnapshot(
    name: _nameCtrl.text,
    battery: _batteryCtrl.text,
    note: _noteCtrl.text,
    photo: _photoDraft,
  );

  String? _nameError;
  String? _batteryError;
  bool _isSaving = false;

  bool get _isDirty =>
      _nameCtrl.text != _snapshot.name ||
      _batteryCtrl.text != _snapshot.battery ||
      _noteCtrl.text != _snapshot.note ||
      _photoDraft != _snapshot.photo;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _batteryCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// 关闭弹层：草稿有改动时二次确认。
  Future<void> _handleCloseRequest() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('放弃编辑'),
        content: const Text('内容尚未保存，确定放弃？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 拍照 / 相册选图（选填），选中后仅存临时路径，保存时才落盘。
  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 90,
      );
      if (picked == null) return; // 用户取消不算错误
      setState(() => _photoDraft = picked.path);
    } on Exception catch (e) {
      appLogger.e('选图失败(vehicle): $e');
      if (mounted) showAppToast(context, '选择图片失败，请重试');
    }
  }

  void _clearPhoto() => setState(() => _photoDraft = '');

  /// 前置校验给出精确文案；buildVehicleFromForm 作最终守卫兜底。
  bool _showValidationErrors() {
    final nameError = normalizeVehicleName(_nameCtrl.text) == null
        ? '请输入 1-20 字的昵称'
        : null;
    final batteryError = parseBattery(_batteryCtrl.text) == null
        ? '请输入 15-200 的电池容量'
        : null;
    setState(() {
      _nameError = nameError;
      _batteryError = batteryError;
    });
    return nameError != null || batteryError != null;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_showValidationErrors()) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final vehicle = buildVehicleFromForm(
      VehicleForm(
        name: _nameCtrl.text,
        battery: _batteryCtrl.text,
        note: _noteCtrl.text,
      ),
      now,
    );
    if (vehicle == null) {
      showAppToast(context, '请检查输入内容');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final store = await ref.read(photoStoreProvider.future);
      final editing = widget.vehicle;
      if (editing == null) {
        var toAdd = vehicle;
        if (_photoDraft.isNotEmpty) {
          // 新选临时文件 → 先落盘
          final filename = await store.save(
            sourcePath: _photoDraft,
            key: vehicle.id,
          );
          toAdd = vehicle.copyWith(photoPath: filename);
        }
        await ref.read(vehiclesProvider.notifier).add(toAdd);
      } else {
        String? photoPath; // null = 保持不变；'' = 清除
        if (_photoDraft != editing.photoPath) {
          photoPath = _photoDraft.isEmpty
              ? ''
              : await store.save(sourcePath: _photoDraft, key: editing.id);
        }
        await ref
            .read(vehiclesProvider.notifier)
            .update(
              editing.id,
              name: vehicle.name,
              battery: vehicle.battery,
              note: vehicle.note,
              photoPath: photoPath,
            );
        // 清除/替换旧照片文件（尽力而为）
        if (photoPath != null &&
            editing.photoPath.isNotEmpty &&
            photoPath != editing.photoPath) {
          unawaited(store.delete(editing.photoPath));
        }
      }
      if (mounted) {
        Navigator.of(context).pop();
        showAppToast(context, '已保存');
      }
    } on PhotoStoreException catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        showAppToast(context, e.message);
      }
    } on Exception {
      if (mounted) {
        setState(() => _isSaving = false);
        showAppToast(context, '保存失败，请重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleCloseRequest());
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _FieldLabel(
                label: '昵称',
                errorText: _nameError,
                child: TextField(
                  controller: _nameCtrl,
                  maxLength: vehicleNameMaxLength,
                  decoration: const InputDecoration(
                    counterText: '',
                    isDense: true,
                    hintText: '如：小白',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                  ),
                  onChanged: (_) {
                    if (_nameError != null) {
                      setState(() => _nameError = null);
                    }
                  },
                ),
              ),
              const SizedBox(height: 14),
              _FieldLabel(
                label: '电池容量（kWh）',
                errorText: _batteryError,
                child: TextField(
                  controller: _batteryCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '如 60',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                  ),
                  onChanged: (_) {
                    if (_batteryError != null) {
                      setState(() => _batteryError = null);
                    }
                  },
                ),
              ),
              const SizedBox(height: 14),
              _FieldLabel(
                label: '备注（选填）',
                child: TextField(
                  controller: _noteCtrl,
                  maxLength: vehicleNoteMaxLength,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    counterText: '',
                    isDense: true,
                    hintText: '例如：家充为主、白色 Model 3',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PhotoPreview(photoPath: _photoDraft),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '车辆照片（选填）',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            _PhotoActionText(
                              text: '拍照',
                              onTap: () => _pickPhoto(ImageSource.camera),
                            ),
                            _PhotoActionText(
                              text: '从相册选择',
                              onTap: () => _pickPhoto(ImageSource.gallery),
                            ),
                            if (_photoDraft.isNotEmpty)
                              _PhotoActionText(
                                text: '移除',
                                isDestructive: true,
                                onTap: _clearPhoto,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(text: '保存', onTap: _isSaving ? null : _save),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹层打开时的草稿快照。
class _SheetSnapshot {
  const _SheetSnapshot({
    required this.name,
    required this.battery,
    required this.note,
    required this.photo,
  });

  final String name;
  final String battery;
  final String note;
  final String photo;
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.child, this.errorText});

  final String label;
  final Widget child;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: palette.textSecondary),
        ),
        const SizedBox(height: 6),
        child,
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: TextStyle(fontSize: 11, color: palette.error),
          ),
        ],
      ],
    );
  }
}

/// 照片预览圆角块（新选临时路径或已存持久文件）。
///
/// 新选的照片是图片选择器的临时绝对路径，直接渲染；
/// 已存的裸文件名经 [PhotoStore] 解析（存储未就绪/文件缺失回退相机图标）。
class _PhotoPreview extends ConsumerWidget {
  const _PhotoPreview({required this.photoPath});

  final String photoPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: palette.inputBg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildImage(context, ref),
    );
  }

  Widget _buildImage(BuildContext context, WidgetRef ref) {
    final placeholder = Icon(
      Icons.photo_camera_rounded,
      size: 24,
      color: context.palette.textHint,
    );
    if (photoPath.isEmpty) {
      return placeholder;
    }
    if (photoPath.contains('/')) {
      return Image.file(
        File(photoPath),
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    final store = ref.watch(photoStoreProvider);
    final resolved = store.valueOrNull;
    if (resolved == null || !resolved.exists(photoPath)) {
      return placeholder;
    }
    return Image.file(
      File(resolved.resolvePath(photoPath)),
      width: 72,
      height: 72,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

class _PhotoActionText extends StatelessWidget {
  const _PhotoActionText({
    required this.text,
    required this.onTap,
    this.isDestructive = false,
  });

  final String text;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: isDestructive ? palette.error : palette.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
