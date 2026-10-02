import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/charge_map.dart';
import 'package:ev_tool_app/core/domain/data/city_coords.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/app_primary_button.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart' show showAppToast;
import 'package:ev_tool_app/core/domain/ocr_receipt.dart';
import 'package:ev_tool_app/features/ocr/presentation/widgets/ocr_entry_card.dart';
import 'package:ev_tool_app/features/records/data/repositories/draft_repository.dart';
import 'package:ev_tool_app/features/records/presentation/providers/records_provider.dart';

/// 添加/编辑充电记录页（移植小程序 record-add，OCR 入口 Phase 8 接入）。
class RecordAddPage extends ConsumerStatefulWidget {
  const RecordAddPage({super.key, this.recordId});

  /// 编辑目标 id（null 为新增）。
  final String? recordId;

  static const String draftKey = 'record-add';
  static const Duration _draftDebounce = Duration(milliseconds: 300);

  @override
  ConsumerState<RecordAddPage> createState() => _RecordAddPageState();
}

class _RecordAddPageState extends ConsumerState<RecordAddPage> {
  final _formKey = GlobalKey<FormState>();
  final _costController = TextEditingController();
  final _energyController = TextEditingController();
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  final _noteController = TextEditingController();
  final _scrollController = ScrollController();

  String _type = 'fast';
  DateTime _date = DateTime.now();
  String? _vehicleId;
  String? _vehicleName;
  String? _province;
  String? _city;
  String? _locationName;
  Timer? _draftTimer;
  bool _initialized = false;

  bool get _isEdit => widget.recordId != null;

  ChargeRecord? get _editingRecord {
    final id = widget.recordId;
    if (id == null) return null;
    for (final record in ref.read(recordsProvider)) {
      if (record.id == id) return record;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initForm());
    for (final controller in [
      _costController,
      _energyController,
      _hoursController,
      _minutesController,
      _noteController,
    ]) {
      controller.addListener(_scheduleDraftSave);
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    for (final controller in [
      _costController,
      _energyController,
      _hoursController,
      _minutesController,
      _noteController,
    ]) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  /// 编辑模式回填；新增模式提示恢复草稿。
  void _initForm() {
    if (_initialized || !mounted) return;
    _initialized = true;
    if (_isEdit) {
      final record = _editingRecord;
      if (record == null) return;
      setState(() {
        _type = record.type;
        _date = DateTime.tryParse(record.date) ?? DateTime.now();
        _costController.text = record.cost == record.cost.roundToDouble()
            ? record.cost.round().toString()
            : record.cost.toString();
        _energyController.text = record.energy == record.energy.roundToDouble()
            ? record.energy.round().toString()
            : record.energy.toString();
        if (record.durationMinutes != null) {
          _hoursController.text = '${record.durationMinutes! ~/ 60}';
          _minutesController.text = '${record.durationMinutes! % 60}';
        }
        _noteController.text = record.note;
        _vehicleId = record.vehicleId;
        _vehicleName = record.vehicleName;
        _province = record.province;
        _city = record.city;
        _locationName = record.locationName;
      });
      return;
    }
    _offerRestoreDraft();
  }

  Future<void> _offerRestoreDraft() async {
    final draft = ref
        .read(draftRepositoryProvider)
        .getDraft(RecordAddPage.draftKey);
    if (draft == null || draft.isEmpty || !mounted) return;
    final restore = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('恢复草稿'),
        content: const Text('检测到未保存的草稿，是否恢复？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('放弃'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (restore != true || !mounted) {
      await ref
          .read(draftRepositoryProvider)
          .clearDraft(RecordAddPage.draftKey);
      return;
    }
    setState(() {
      final form = ChargeRecordForm.fromMap(draft);
      _type = form.type is String ? form.type as String : _type;
      _costController.text = (form.cost ?? '').toString();
      _energyController.text = (form.energy ?? '').toString();
      _hoursController.text = (form.hours ?? '').toString();
      _minutesController.text = (form.minutes ?? '').toString();
      _noteController.text = (form.note ?? '').toString();
    });
  }

  void _scheduleDraftSave() {
    // 度电成本实时提示依赖 controller 文本，输入变化即重建
    if (mounted) setState(() {});
    if (_isEdit) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(RecordAddPage._draftDebounce, _saveDraft);
  }

  Future<void> _saveDraft() async {
    final draft = {
      for (final entry in _collectForm().toMap().entries)
        if (entry.value != null && entry.value != '') entry.key: entry.value,
    };
    if (draft.length <= 2) return; // 只有 type/date 不值得存
    try {
      await ref
          .read(draftRepositoryProvider)
          .saveDraft(RecordAddPage.draftKey, draft);
    } on Exception {
      // 草稿保存失败静默（非关键路径）
    }
  }

  /// OCR 识别结果回填表单（覆盖式，值有效才填）。
  void _applyReceiptResult(ReceiptResult result) {
    setState(() {
      if (result.cost.isNotEmpty) _costController.text = result.cost;
      if (result.energy.isNotEmpty) _energyController.text = result.energy;
      if (result.hours.isNotEmpty) _hoursController.text = result.hours;
      if (result.minutes.isNotEmpty) _minutesController.text = result.minutes;
      if (result.note.isNotEmpty) _noteController.text = result.note;
      final date = DateTime.tryParse(result.date);
      if (date != null && !date.isAfter(DateTime.now())) _date = date;
      if (result.chargeType == 'fast' || result.chargeType == 'home') {
        _type = result.chargeType;
      }
    });
  }

  ChargeRecordForm _collectForm() => ChargeRecordForm(
    type: _type,
    date:
        '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
    cost: _costController.text,
    energy: _energyController.text,
    hours: _hoursController.text,
    minutes: _minutesController.text,
    note: _noteController.text,
    vehicleId: _vehicleId,
    vehicleName: _vehicleName,
    province: _province,
    city: _city,
    locationName: _locationName,
  );

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickVehicle() async {
    final vehicles = ref.read(vehiclesProvider);
    final selected = await showAppSheet<String>(
      context: context,
      title: '选择车辆',
      builder: (context) => AppSheetScrollBody(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _VehicleChip(
              label: '暂不关联',
              isSelected: _vehicleId == null,
              onTap: () => Navigator.of(context).pop(''),
            ),
            for (final vehicle in vehicles)
              _VehicleChip(
                label: vehicle.name,
                isSelected: _vehicleId == vehicle.id,
                onTap: () =>
                    Navigator.of(context).pop('${vehicle.id}|${vehicle.name}'),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    if (selected.isEmpty) {
      setState(() {
        _vehicleId = null;
        _vehicleName = null;
      });
      return;
    }
    final parts = selected.split('|');
    setState(() {
      _vehicleId = parts.first;
      _vehicleName = parts.length > 1 ? parts.sublist(1).join('|') : null;
    });
  }

  /// 省市选择（两连弹层：省 → 市），城市归一到预设简称并回填坐标。
  Future<void> _pickRegion() async {
    final province = await showAppSheet<String>(
      context: context,
      title: '选择省份',
      builder: (context) => AppSheetScrollBody(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final name in cityCoords.keys)
              _VehicleChip(
                label: name,
                isSelected: _province == name,
                onTap: () => Navigator.of(context).pop(name),
              ),
          ],
        ),
      ),
    );
    if (province == null || !mounted) return;
    final cities = cityCoords[province] ?? const <CityCoord>[];
    final city = await showAppSheet<String>(
      context: context,
      title: '选择城市',
      builder: (context) => AppSheetScrollBody(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in cities)
              _VehicleChip(
                label: entry.name,
                isSelected: _city == entry.name,
                onTap: () => Navigator.of(context).pop(entry.name),
              ),
          ],
        ),
      ),
    );
    if (city == null || !mounted) return;
    setState(() {
      _province = province;
      _city = matchCity(province, city) ?? city;
      _locationName = null;
    });
  }

  Future<void> _save() async {
    if (!(validateAndSaveForm())) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final built = buildRecordFromForm(_collectForm(), now: now);
    if (built == null) {
      showAppToast(context, '请检查表单填写');
      return;
    }
    final notifier = ref.read(recordsProvider.notifier);
    try {
      if (_isEdit) {
        final editing = _editingRecord;
        if (editing == null) return;
        await notifier.update(
          editing.id,
          built.copyWith(
            vehicleId: _vehicleId,
            vehicleName: _vehicleName,
            province: _province,
            city: _city,
            locationName: _locationName,
          ),
        );
      } else {
        await notifier.add(
          built.copyWith(
            vehicleId: _vehicleId,
            vehicleName: _vehicleName,
            province: _province,
            city: _city,
            locationName: _locationName,
          ),
        );
        await ref
            .read(draftRepositoryProvider)
            .clearDraft(RecordAddPage.draftKey);
      }
      if (!mounted) return;
      showAppToast(context, _isEdit ? '已更新' : '已添加');
      Navigator.of(context).pop();
    } on Exception {
      if (mounted) showAppToast(context, '保存失败，请重试');
    }
  }

  bool validateAndSaveForm() {
    final cost = toNumber(_costController.text);
    final energy = toNumber(_energyController.text);
    var valid = true;
    if (cost == null || cost <= 0) {
      _markError('费用需为正数');
      valid = false;
    }
    if (energy == null || energy <= 0) {
      _markError('电量需为正数');
      valid = false;
    }
    if (!valid && mounted) {
      HapticFeedback.lightImpact();
    }
    return valid;
  }

  void _markError(String message) {
    if (mounted) showAppToast(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cost = toNumber(_costController.text);
    final energy = toNumber(_energyController.text);
    final perKwh = cost != null && energy != null && energy > 0
        ? calcCostPerKwh(cost, energy)
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '编辑充电记录' : '添加充电记录')),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            OcrEntryCard(onResult: _applyReceiptResult),
            const SizedBox(height: 12),
            _FormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('充电类型'),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeChip(
                          label: '快充',
                          icon: Icons.bolt_rounded,
                          isSelected: _type == 'fast',
                          onTap: () => setState(() => _type = 'fast'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TypeChip(
                          label: '家充',
                          icon: Icons.home_rounded,
                          isSelected: _type == 'home',
                          onTap: () => setState(() => _type = 'home'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel('充电日期'),
                  _PickerField(
                    value:
                        '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                    icon: Icons.calendar_month_rounded,
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _NumberField(
                          label: '费用（元）',
                          hint: '如 45.5',
                          controller: _costController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumberField(
                          label: '电量（kWh）',
                          hint: '如 30.2',
                          controller: _energyController,
                        ),
                      ),
                    ],
                  ),
                  if (perKwh != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '度电成本约 ${formatYuan(perKwh)} 元/kWh',
                      style: TextStyle(fontSize: 12, color: palette.primary),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const _FieldLabel('充电时长'),
                  Row(
                    children: [
                      Expanded(
                        child: _NumberField(
                          label: '小时',
                          hint: '如 2',
                          controller: _hoursController,
                          allowDecimal: false,
                          maxDigits: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumberField(
                          label: '分钟',
                          hint: '如 30',
                          controller: _minutesController,
                          allowDecimal: false,
                          maxDigits: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _FormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('关联车辆（选填）'),
                  _PickerField(
                    value: _vehicleName ?? '暂不关联',
                    icon: Icons.directions_car_rounded,
                    onTap: _pickVehicle,
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel('充电地点（选填）'),
                  _PickerField(
                    value:
                        [
                          _city,
                          _locationName,
                        ].whereType<String>().join(' · ').isNotEmpty
                        ? [_city, _locationName].whereType<String>().join(' · ')
                        : '选择省市',
                    icon: Icons.place_rounded,
                    onTap: _pickRegion,
                    trailing: (_city != null || _locationName != null)
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() {
                              _province = null;
                              _city = null;
                              _locationName = null;
                            }),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _NumberField(
                    label: '备注（选填，最多 100 字）',
                    controller: _noteController,
                    isMultiline: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(text: _isEdit ? '保存修改' : '添加记录', onTap: _save),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: context.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? palette.secondaryContainer : palette.inputBg,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          border: Border.all(
            color: isSelected ? palette.primaryContainer : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? palette.onSecondaryContainer
                  : palette.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? palette.onSecondaryContainer
                    : palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.value,
    required this.icon,
    this.onTap,
    this.trailing,
  });

  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: palette.inputBg,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: palette.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: TextStyle(fontSize: 14, color: palette.onSurface),
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: palette.textHint,
              ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    this.hint,
    this.allowDecimal = true,
    this.maxDigits,
    this.isMultiline = false,
  });

  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool allowDecimal;
  final int? maxDigits;
  final bool isMultiline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isMultiline
              ? TextInputType.multiline
              : (allowDecimal
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.number),
          maxLength: maxDigits,
          maxLines: isMultiline ? 3 : 1,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              allowDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
            ),
          ],
          // 单行数字输入（费用/电量/小时/分钟）收紧内边距降低高度
          decoration: InputDecoration(
            counterText: '',
            isDense: true,
            hintText: hint,
            contentPadding: isMultiline
                ? null
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    );
  }
}

class _VehicleChip extends StatelessWidget {
  const _VehicleChip({
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
    return InkWell(
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? palette.secondaryContainer : palette.inputBg,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          border: Border.all(
            color: isSelected ? palette.primaryContainer : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
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
