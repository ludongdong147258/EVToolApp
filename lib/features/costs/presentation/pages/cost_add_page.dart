import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/maintenance_costs.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/app_primary_button.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart' show showAppToast;
import 'package:ev_tool_app/features/costs/presentation/providers/costs_provider.dart';
import 'package:ev_tool_app/features/costs/presentation/widgets/cost_card.dart'
    show expenseTypeIcon;
import 'package:ev_tool_app/features/records/data/repositories/draft_repository.dart';
import 'package:ev_tool_app/features/records/presentation/providers/records_provider.dart'
    show vehiclesProvider;

/// 新增/编辑养车支出页（移植小程序 cost-add）。
///
/// 编辑模式经 `?id=<支出id>` 进入；新增模式草稿落盘
/// `formDraft:cost-add`（编辑模式不启用）。
class CostAddPage extends ConsumerStatefulWidget {
  const CostAddPage({super.key, this.expenseId});

  /// 编辑目标 id（null 为新增）。
  final String? expenseId;

  static const String draftKey = 'cost-add';
  static const Duration _draftDebounce = Duration(milliseconds: 300);

  @override
  ConsumerState<CostAddPage> createState() => _CostAddPageState();
}

class _CostAddPageState extends ConsumerState<CostAddPage> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _type = 'maintenance';
  DateTime _date = DateTime.now();
  String? _vehicleId;
  String? _vehicleName;
  String? _amountError;
  Timer? _draftTimer;
  bool _initialized = false;

  bool get _isEdit => widget.expenseId != null;

  Expense? get _editingExpense {
    final id = widget.expenseId;
    if (id == null) return null;
    for (final expense in ref.read(costsProvider)) {
      if (expense.id == id) return expense;
    }
    return null;
  }

  String get _dateStr =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}'
      '-${_date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initForm());
    _amountController.addListener(_scheduleDraftSave);
    _noteController.addListener(_scheduleDraftSave);
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// 编辑模式回填；新增模式默认车预选 + 提示恢复草稿。
  void _initForm() {
    if (_initialized || !mounted) return;
    _initialized = true;
    if (_isEdit) {
      final expense = _editingExpense;
      // 查不到降级为新增模式（不让页面崩在挂载期）
      if (expense == null) return;
      setState(() {
        _type = expense.type;
        _date = DateTime.tryParse(expense.date) ?? DateTime.now();
        _amountController.text = _stripTrailingZero(expense.amount);
        _noteController.text = expense.note;
        _vehicleId = expense.vehicleId;
        _vehicleName = expense.vehicleName;
      });
      return;
    }
    final vehicles = ref.read(vehiclesProvider);
    final defaultVehicle =
        vehicles.where((v) => v.isDefault).firstOrNull ?? vehicles.firstOrNull;
    if (defaultVehicle != null) {
      setState(() {
        _vehicleId = defaultVehicle.id;
        _vehicleName = defaultVehicle.name;
      });
    }
    _offerRestoreDraft();
  }

  String _stripTrailingZero(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toString();

  Future<void> _offerRestoreDraft() async {
    final draft = ref
        .read(draftRepositoryProvider)
        .getDraft(CostAddPage.draftKey);
    if (draft == null || !mounted) return;
    // 全空草稿静默清除，不打扰用户
    final hasContent = [
      draft['amount'],
      draft['note'],
    ].any((field) => field != null && field.toString().trim().isNotEmpty);
    if (!hasContent) {
      await ref.read(draftRepositoryProvider).clearDraft(CostAddPage.draftKey);
      return;
    }
    final restore = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('恢复草稿'),
        content: const Text('检测到未保存的草稿，是否恢复？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('不恢复'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (restore != true || !mounted) {
      await ref.read(draftRepositoryProvider).clearDraft(CostAddPage.draftKey);
      return;
    }
    setState(() {
      final draftDate = draft['date'];
      if (draftDate is String) {
        _date = DateTime.tryParse(draftDate) ?? _date;
      }
      final draftType = draft['type'];
      if (draftType is String && expenseTypes.contains(draftType)) {
        _type = draftType;
      }
      _amountController.text = (draft['amount'] ?? '').toString();
      _noteController.text = (draft['note'] ?? '').toString();
      final draftVehicleId = draft['vehicleId'];
      if (draftVehicleId is String && draftVehicleId.isNotEmpty) {
        _vehicleId = draftVehicleId;
        final vehicles = ref.read(vehiclesProvider);
        _vehicleName = vehicles
            .where((v) => v.id == draftVehicleId)
            .firstOrNull
            ?.name;
      }
    });
  }

  void _scheduleDraftSave() {
    if (_isEdit) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(CostAddPage._draftDebounce, _saveDraft);
  }

  /// 类型/日期/车辆等非输入框字段变化时手动触发。
  void _markFormChanged() {
    if (!_isEdit) _scheduleDraftSave();
  }

  Future<void> _saveDraft() async {
    final draft = <String, dynamic>{
      'date': _dateStr,
      'type': _type,
      'amount': _amountController.text,
      'note': _noteController.text,
      'vehicleId': _vehicleId,
    };
    try {
      await ref
          .read(draftRepositoryProvider)
          .saveDraft(CostAddPage.draftKey, draft);
    } on Exception {
      // 草稿保存失败静默（非关键路径）
    }
  }

  /// 有效金额：非空字符串且可转为 >= 0.01 的数值。
  bool _isValidAmount(String value) {
    final num = toNumber(value);
    return value.trim().isNotEmpty && num != null && num >= 0.01;
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(2020),
      lastDate: today, // 不可选未来日期
    );
    if (picked != null) {
      setState(() => _date = picked);
      _markFormChanged();
    }
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
    if (selected == null || !mounted) return;
    setState(() {
      if (selected.isEmpty) {
        // 「暂不关联」（编辑旧记录/主动取消关联）
        _vehicleId = null;
        _vehicleName = null;
      } else {
        final parts = selected.split('|');
        _vehicleId = parts.first;
        _vehicleName = parts.length > 1 ? parts.sublist(1).join('|') : null;
      }
    });
    _markFormChanged();
  }

  Future<void> _save() async {
    final amountText = _amountController.text;
    if (!_isValidAmount(amountText)) {
      setState(() => _amountError = '请输入有效金额');
      showAppToast(context, '请检查标红字段');
      return;
    }
    setState(() => _amountError = null);
    final built = buildExpenseFromForm(
      ExpenseForm(
        type: _type,
        date: _dateStr,
        amount: amountText,
        note: _noteController.text,
        vehicleId: _vehicleId,
        vehicleName: _vehicleName,
      ),
      DateTime.now().millisecondsSinceEpoch,
    );
    if (built == null) {
      showAppToast(context, '请检查日期和金额输入');
      return;
    }
    final notifier = ref.read(costsProvider.notifier);
    try {
      if (_isEdit) {
        final editing = _editingExpense;
        if (editing == null) return;
        await notifier.update(editing.id, built);
      } else {
        _draftTimer?.cancel();
        await notifier.add(built);
        await ref
            .read(draftRepositoryProvider)
            .clearDraft(CostAddPage.draftKey);
      }
      if (!mounted) return;
      unawaited(HapticFeedback.lightImpact());
      showAppToast(context, '保存成功');
      Navigator.of(context).pop();
    } on Exception {
      if (mounted) showAppToast(context, '保存失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final vehicles = ref.watch(vehiclesProvider);
    final selectedVehicle = vehicles
        .where((v) => v.id == _vehicleId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '编辑养车支出' : '新增养车支出')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('支出类型'),
                // 8 类型 chip 网格单选
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in expenseTypes)
                      _TypeChip(
                        label: EXPENSE_TYPE_META[type]?.label ?? type,
                        icon: expenseTypeIcon(type),
                        color: AppColors.costTypeColor(type),
                        isSelected: _type == type,
                        onTap: () {
                          setState(() => _type = type);
                          _markFormChanged();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const _FieldLabel('支出日期'),
                _PickerField(
                  value: formatDateCn(_dateStr),
                  icon: Icons.calendar_month_rounded,
                  onTap: _pickDate,
                ),
                const SizedBox(height: 16),
                const _FieldLabel('支出金额（元）'),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    hintText: '0.00',
                    suffixText: '元',
                    errorText: _amountError,
                  ),
                  onChanged: (_) {
                    if (_amountError != null) {
                      setState(() => _amountError = null);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const _FieldLabel('关联车辆（选填）'),
                if (vehicles.isEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car_rounded,
                        size: 18,
                        color: palette.textHint,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '在「我的 → 我的车辆」添加后可关联',
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.textHint,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  _PickerField(
                    value: selectedVehicle == null
                        ? '暂不关联'
                        : selectedVehicle.name,
                    icon: Icons.directions_car_rounded,
                    onTap: _pickVehicle,
                  ),
                const SizedBox(height: 16),
                const _FieldLabel('备注（选填，最多 100 字）'),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  maxLength: expenseNoteMaxLength,
                  decoration: const InputDecoration(
                    hintText: '例如：小区月停车费、4S 店首保',
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppPrimaryButton(text: _isEdit ? '保存修改' : '保存账单', onTap: _save),
          const SizedBox(height: 32),
        ],
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

/// 支出类型 chip（图标恒为类型色，选中态容器高亮）。
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.14) : palette.inputBg,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          border: Border.all(color: isSelected ? color : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected
                    ? palette.onSurface
                    : palette.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({required this.value, required this.icon, this.onTap});

  final String value;
  final IconData icon;
  final VoidCallback? onTap;

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
            Icon(Icons.expand_more_rounded, size: 18, color: palette.textHint),
          ],
        ),
      ),
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
