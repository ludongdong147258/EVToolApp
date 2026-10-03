import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/core/domain/inspection_memo_calc.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/domain/vehicles.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/routing/route_names.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/theme/app_palette.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart' show showAppToast;
import 'package:ev_tool_app/core/widgets/empty_state.dart';
import 'package:ev_tool_app/core/widgets/gradient_hero_card.dart';
import 'package:ev_tool_app/features/memos/data/repositories/memo_repository.dart';
import 'package:ev_tool_app/features/records/presentation/providers/records_provider.dart';

/// 时间轴展示的 upcoming 节点条数（移植小程序 TIMELINE_COUNT）。
const int _timelineCount = 4;

/// 里程输入合法性：正数且不超上限。
bool _isValidMileage(String value) =>
    isValidPositiveNumber(value, max: mileageMax);

/// 车龄整年数（未到周年日扣 1）。
int? _getAgeYears(String registrationDate) {
  final reg = parseDateStr(registrationDate);
  if (reg == null) {
    return null;
  }
  final now = DateTime.now();
  var years = now.year - reg.year;
  final beforeAnniversary =
      now.month < reg.month || (now.month == reg.month && now.day < reg.day);
  if (beforeAnniversary) {
    years -= 1;
  }
  return years < 0 ? 0 : years;
}

IconData _memoIcon(String name) => switch (name) {
  'build' => Icons.build_rounded,
  'speed' => Icons.speed_rounded,
  'warning' => Icons.warning_amber_rounded,
  'directions_car' => Icons.directions_car_rounded,
  'task_alt' => Icons.task_alt_rounded,
  'verified_user' => Icons.verified_user_rounded,
  'menu_book' => Icons.menu_book_rounded,
  'calendar_month' => Icons.calendar_month_rounded,
  'edit' => Icons.edit_rounded,
  'schedule' => Icons.schedule_rounded,
  _ => Icons.info_outline_rounded,
};

Color _statusColor(String status, EvPalette palette) => switch (status) {
  statusOverdue => palette.error,
  statusSoon => AppColors.amber,
  _ => palette.textHint,
};

/// 计算结果（三块互相独立，任一有效即非 null）。
class _MemoResult {
  const _MemoResult({this.inspection, this.maintenance, this.insurance});

  final InspectionSchedule? inspection;
  final List<MaintenanceNodeStatus>? maintenance;
  final InsuranceStatus? insurance;
}

_MemoResult? _computeResult(
  String registrationDate,
  String mileageKm,
  String insuranceExpiryDate,
) {
  final inspection = calcInspectionSchedule(registrationDate);
  final maintenance = calcMaintenanceNodes(registrationDate, mileageKm);
  final insurance = calcInsuranceStatus(
    insuranceExpiryDate.isEmpty ? null : insuranceExpiryDate,
  );
  if (inspection == null && maintenance == null && insurance == null) {
    return null;
  }
  return _MemoResult(
    inspection: inspection,
    maintenance: maintenance,
    insurance: insurance,
  );
}

/// 年检维保备忘录页（移植小程序 inspection-memo）：
/// 录入上牌日期与里程，推算年检时间轴与维保节点。
class InspectionMemoPage extends ConsumerStatefulWidget {
  const InspectionMemoPage({super.key});

  @override
  ConsumerState<InspectionMemoPage> createState() => _InspectionMemoPageState();
}

class _InspectionMemoPageState extends ConsumerState<InspectionMemoPage> {
  final _mileageController = TextEditingController();

  String? _selectedVehicleId;
  String _registrationDate = '';
  String _insuranceExpiryDate = '';
  bool _selectedIsOrphan = false;

  @override
  void initState() {
    super.initState();
    // 默认选中第一辆车；有备忘则连同表单一次写入（避免结果区闪空）
    final vehicles = ref.read(vehiclesProvider);
    if (vehicles.isEmpty) {
      return;
    }
    final vehicle = vehicles.first;
    MemoItem? memo;
    for (final item in ref.read(memoListProvider)) {
      if (item.vehicleId == vehicle.id) {
        memo = item;
        break;
      }
    }
    _selectedVehicleId = vehicle.id;
    if (memo != null) {
      _registrationDate = memo.registrationDate;
      _mileageController.text = '${memo.mileageKm}';
      _insuranceExpiryDate = memo.insuranceExpiryDate ?? '';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 从车辆页返回时刷新；当前选中失效且非孤儿备忘时重置
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshOnShow());
  }

  void _refreshOnShow() {
    if (!mounted) return;
    ref.read(vehiclesProvider.notifier).reload();
    final vehicles = ref.read(vehiclesProvider);
    final memos = ref.read(memoListProvider);
    final id = _selectedVehicleId;
    if (id == null) {
      return;
    }
    final stillExists = vehicles.any((item) => item.id == id);
    final stillOrphan = memos.any((memo) => memo.vehicleId == id);
    if (!stillExists && !stillOrphan) {
      _resetForm();
    }
  }

  @override
  void dispose() {
    _mileageController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _selectedVehicleId = null;
      _selectedIsOrphan = false;
      _registrationDate = '';
      _insuranceExpiryDate = '';
      _mileageController.clear();
    });
  }

  /// 切车：预填该车备忘，无备忘则清空表单。
  void _applyVehicleSelection(String vehicleId) {
    Vehicle? vehicle;
    for (final item in ref.read(vehiclesProvider)) {
      if (item.id == vehicleId) {
        vehicle = item;
        break;
      }
    }
    MemoItem? memo;
    for (final item in ref.read(memoListProvider)) {
      if (item.vehicleId == vehicleId) {
        memo = item;
        break;
      }
    }
    if (vehicle == null && memo == null) {
      return;
    }
    setState(() {
      _selectedVehicleId = vehicleId;
      _selectedIsOrphan = vehicle == null;
      _registrationDate = '';
      _insuranceExpiryDate = '';
      _mileageController.clear();
      if (memo != null) {
        _registrationDate = memo.registrationDate;
        _mileageController.text = '${memo.mileageKm}';
        _insuranceExpiryDate = memo.insuranceExpiryDate ?? '';
      }
    });
  }

  Future<void> _openVehicleSheet() async {
    final vehicles = ref.read(vehiclesProvider);
    final memos = ref.read(memoListProvider);
    final orphanIds = {
      for (final memo in memos)
        if (!vehicles.any((vehicle) => vehicle.id == memo.vehicleId))
          memo.vehicleId,
    };
    final selected = await showAppSheet<String>(
      context: context,
      title: 'Select vehicle',
      builder: (sheetContext) => AppSheetScrollBody(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final vehicle in vehicles)
              _VehicleChip(
                label: vehicle.name,
                isSelected: _selectedVehicleId == vehicle.id,
                onTap: () => Navigator.of(sheetContext).pop(vehicle.id),
              ),
            for (final memo in memos.where(
              (memo) => orphanIds.contains(memo.vehicleId),
            ))
              _VehicleChip(
                label:
                    '${memo.vehicleName.isEmpty ? 'Unnamed vehicle' : memo.vehicleName}'
                    ' · Deleted',
                isSelected: _selectedVehicleId == memo.vehicleId,
                onTap: () => Navigator.of(sheetContext).pop(memo.vehicleId),
              ),
          ],
        ),
      ),
    );
    if (selected == null) {
      return;
    }
    _applyVehicleSelection(selected);
  }

  Future<void> _pickRegistrationDate() async {
    final initial = parseDateStr(_registrationDate) ?? DateTime.now();
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(today) ? today : initial,
      firstDate: DateTime(1990),
      lastDate: today,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _registrationDate =
          '${picked.year}-${pad2(picked.month)}-${pad2(picked.day)}';
    });
  }

  Future<void> _pickInsuranceDate() async {
    final initial = parseDateStr(_insuranceExpiryDate) ?? DateTime.now();
    // 不设 end 上限：到期日为未来，也允许选过去以纠正
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _insuranceExpiryDate =
          '${picked.year}-${pad2(picked.month)}-${pad2(picked.day)}';
    });
  }

  Future<void> _save() async {
    final vehicleId = _selectedVehicleId;
    if (vehicleId == null) {
      showAppToast(context, 'Select a vehicle first');
      return;
    }
    if (parseDateStr(_registrationDate) == null) {
      showAppToast(context, 'Select the registration date');
      return;
    }
    final mileage = toNumber(_mileageController.text);
    if (mileage == null || !_isValidMileage(_mileageController.text)) {
      showAppToast(context, 'Enter a valid mileage');
      return;
    }
    final vehicleName = _resolveVehicleName(vehicleId);
    try {
      await ref
          .read(memoRepositoryProvider)
          .saveMemo(
            MemoItem(
              id: '',
              vehicleId: vehicleId,
              vehicleName: vehicleName,
              registrationDate: _registrationDate,
              mileageKm: mileage.round(),
              insuranceExpiryDate: _insuranceExpiryDate.isEmpty
                  ? null
                  : _insuranceExpiryDate,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    } on Exception catch (e) {
      appLogger.e('Failed to save inspection memo', error: e);
      if (mounted) showAppToast(context, 'Save failed');
      return;
    }
    // 联动记录页提醒条与底栏红点（替代小程序 MEMO_CHANGE 事件）
    ref.invalidate(memoListProvider);
    unawaited(HapticFeedback.lightImpact());
    if (mounted) showAppToast(context, 'Saved');
  }

  String _resolveVehicleName(String vehicleId) {
    for (final vehicle in ref.read(vehiclesProvider)) {
      if (vehicle.id == vehicleId) {
        return vehicle.name;
      }
    }
    for (final memo in ref.read(memoListProvider)) {
      if (memo.vehicleId == vehicleId) {
        return memo.vehicleName;
      }
    }
    return '';
  }

  Future<void> _confirmDelete(String vehicleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete memo'),
        content: const Text(
          'Delete the inspection & maintenance memo for this vehicle?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.palette.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await ref.read(memoRepositoryProvider).removeMemo(vehicleId);
    } on Exception catch (e) {
      appLogger.e('Failed to delete inspection memo', error: e);
      if (mounted) showAppToast(context, 'Delete failed');
      return;
    }
    ref.invalidate(memoListProvider);
    if (!mounted) {
      return;
    }
    if (vehicleId == _selectedVehicleId) {
      setState(() {
        _registrationDate = '';
        _insuranceExpiryDate = '';
        _mileageController.clear();
      });
    }
    showAppToast(context, 'Deleted');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final vehicles = ref.watch(vehiclesProvider);
    final memos = ref.watch(memoListProvider);

    final mileageText = _mileageController.text;
    final isMileageInvalid =
        mileageText.isNotEmpty && !_isValidMileage(mileageText);
    final result = _computeResult(
      _registrationDate,
      mileageText,
      _insuranceExpiryDate,
    );

    final inspection = result?.inspection;
    final next = inspection?.next;
    final timelinePast = [
      if (inspection?.latestPast != null) inspection!.latestPast!,
    ];
    final timelineUpcoming = [
      if (inspection != null)
        for (final item in inspection.milestones)
          if (item.daysRemaining >= 0) item,
    ].take(_timelineCount).toList();
    final maintenance = result?.maintenance ?? const <MaintenanceNodeStatus>[];
    final insurance = result?.insurance;
    final ageYears = _registrationDate.isEmpty
        ? null
        : _getAgeYears(_registrationDate);

    MemoItem? currentMemo;
    for (final memo in memos) {
      if (memo.vehicleId == _selectedVehicleId) {
        currentMemo = memo;
        break;
      }
    }
    final mileageRounded = (toNumber(mileageText) ?? 0).round();
    final hasUnsavedChanges =
        currentMemo != null &&
        (_registrationDate != currentMemo.registrationDate ||
            mileageRounded != currentMemo.mileageKm ||
            (_insuranceExpiryDate.isEmpty ? null : _insuranceExpiryDate) !=
                currentMemo.insuranceExpiryDate);

    return Scaffold(
      appBar: AppBar(title: const Text('Service & Inspection Memo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Track inspections and maintenance milestones so due dates never '
            'sneak up on you.',
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          const SizedBox(height: 12),
          if (next != null) ...[
            _NextInspectionHero(next: next, ageYears: ageYears),
            const SizedBox(height: 12),
          ],
          _MemoFormCard(
            mileageController: _mileageController,
            vehicles: vehicles,
            memos: memos,
            selectedVehicleId: _selectedVehicleId,
            selectedIsOrphan: _selectedIsOrphan,
            selectedVehicleName: _resolveVehicleName(_selectedVehicleId ?? ''),
            registrationDate: _registrationDate,
            insuranceExpiryDate: _insuranceExpiryDate,
            isMileageInvalid: isMileageInvalid,
            currentMemo: currentMemo,
            hasUnsavedChanges: hasUnsavedChanges,
            onPickVehicle: _openVehicleSheet,
            onPickRegistrationDate: _pickRegistrationDate,
            onPickInsuranceDate: _pickInsuranceDate,
            onGoVehicles: () => context.push(RouteNames.vehicles),
            onSave: _save,
            onDelete: () => _confirmDelete(_selectedVehicleId ?? ''),
          ),
          if (insurance != null) ...[
            const SizedBox(height: 12),
            _InsuranceCard(insurance: insurance),
          ],
          if (timelinePast.isNotEmpty || timelineUpcoming.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TimelineCard(past: timelinePast, upcoming: timelineUpcoming),
          ],
          if (maintenance.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MaintenanceCard(nodes: maintenance),
          ],
          const SizedBox(height: 12),
          const _ScienceCard(),
          if (memos.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SavedMemosCard(
              memos: memos,
              currentVehicleId: _selectedVehicleId,
              onDelete: _confirmDelete,
            ),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              memoDisclaimer,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: palette.textHint),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _NextInspectionHero extends StatelessWidget {
  const _NextInspectionHero({required this.next, required this.ageYears});

  final InspectionMilestone next;
  final int? ageYears;

  @override
  Widget build(BuildContext context) {
    return GradientHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Next inspection · ${next.typeLabel}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.onPrimaryA85,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (next.status == statusSoon)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.onPrimaryA22,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  child: const Text(
                    'Due soon',
                    style: TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          HeroValue(value: '${next.daysRemaining}', unit: 'days'),
          const SizedBox(height: 16),
          HeroStatsRow(
            items: [
              HeroStatItem(
                label: 'Next inspection date',
                value: formatCnDate(next.dueDate),
              ),
              HeroStatItem(label: 'Milestone type', value: next.typeLabel),
              HeroStatItem(
                label: 'Vehicle age',
                value: ageYears == null ? '--' : '$ageYears',
                unit: 'yr',
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 本年检周期进度（上一节点 → 下次年检）
          ClipRRect(
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Container(color: AppColors.onPrimaryA22),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: next.progress.clamp(0, 1),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoFormCard extends StatelessWidget {
  const _MemoFormCard({
    required this.mileageController,
    required this.vehicles,
    required this.memos,
    required this.selectedVehicleId,
    required this.selectedIsOrphan,
    required this.selectedVehicleName,
    required this.registrationDate,
    required this.insuranceExpiryDate,
    required this.isMileageInvalid,
    required this.currentMemo,
    required this.hasUnsavedChanges,
    required this.onPickVehicle,
    required this.onPickRegistrationDate,
    required this.onPickInsuranceDate,
    required this.onGoVehicles,
    required this.onSave,
    required this.onDelete,
  });

  final TextEditingController mileageController;
  final List<Vehicle> vehicles;
  final List<MemoItem> memos;
  final String? selectedVehicleId;
  final bool selectedIsOrphan;
  final String selectedVehicleName;
  final String registrationDate;
  final String insuranceExpiryDate;
  final bool isMileageInvalid;
  final MemoItem? currentMemo;
  final bool hasUnsavedChanges;
  final VoidCallback onPickVehicle;
  final VoidCallback onPickRegistrationDate;
  final VoidCallback onPickInsuranceDate;
  final VoidCallback onGoVehicles;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasSelectable = vehicles.isNotEmpty || memos.isNotEmpty;
    final memo = currentMemo;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_rounded, size: 18, color: palette.primary),
                const SizedBox(width: 6),
                Text(
                  'Memo details',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (memo != null && !hasUnsavedChanges)
                  Flexible(
                    child: Text(
                      'Saved · ${formatTimestampDate(memo.updatedAt)}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: palette.textHint),
                    ),
                  )
                else if (memo != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Unsaved',
                        style: TextStyle(fontSize: 11, color: AppColors.amber),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasSelectable)
              EmptyState(
                compact: true,
                icon: Icons.directions_car_rounded,
                title: 'Add a vehicle first to set up a memo',
                ctaText: 'Add vehicle',
                onCta: onGoVehicles,
              )
            else ...[
              _PickerField(
                label: 'Vehicle',
                value: selectedVehicleId == null
                    ? 'Select'
                    : (selectedVehicleName.isEmpty
                          ? 'Unnamed vehicle'
                          : selectedVehicleName),
                icon: Icons.directions_car_rounded,
                tag: selectedIsOrphan ? 'Vehicle deleted' : null,
                onTap: onPickVehicle,
              ),
              const SizedBox(height: 14),
              _PickerField(
                label: 'Registration date',
                value: registrationDate.isEmpty
                    ? 'Select registration date'
                    : registrationDate,
                icon: Icons.calendar_month_rounded,
                onTap: onPickRegistrationDate,
              ),
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current mileage (km)',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: palette.inputBg,
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      border: Border.all(
                        color: isMileageInvalid
                            ? palette.error
                            : Colors.transparent,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: mileageController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: 'e.g. 25000',
                              counterText: '',
                            ),
                          ),
                        ),
                        Text(
                          'km',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isMileageInvalid) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Enter a mileage between 1 and $mileageMax',
                      style: TextStyle(fontSize: 11, color: palette.error),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              _PickerField(
                label: 'Insurance expiry (optional)',
                value: insuranceExpiryDate.isEmpty
                    ? 'Select insurance expiry date'
                    : insuranceExpiryDate,
                icon: Icons.verified_user_rounded,
                onTap: onPickInsuranceDate,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: onSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primaryContainer,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppColors.radiusLg,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Save memo',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  if (currentMemo != null) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.error,
                          side: BorderSide(color: palette.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppColors.radiusLg,
                            ),
                          ),
                        ),
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.tag,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final String? tag;

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
        InkWell(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: palette.inputBg,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: palette.textHint),
                const SizedBox(width: 8),
                if (tag != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: palette.errorContainer,
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                    child: Text(
                      tag!,
                      style: TextStyle(
                        fontSize: 10,
                        color: palette.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: value.startsWith('Select')
                          ? palette.textHint
                          : palette.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.expand_more_rounded,
                  size: 16,
                  color: palette.textHint,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, this.soonText = 'Soon'});

  final String status;
  final String soonText;

  @override
  Widget build(BuildContext context) {
    if (status != statusSoon && status != statusOverdue) {
      return const SizedBox.shrink();
    }
    final palette = context.palette;
    final color = _statusColor(status, palette);
    final text = status == statusSoon ? soonText : 'Overdue';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}

class _InsuranceCard extends StatelessWidget {
  const _InsuranceCard({required this.insurance});

  final InsuranceStatus insurance;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: 18,
                  color: palette.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Insurance memo',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.task_alt_rounded, size: 16, color: palette.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Compulsory / commercial insurance'),
                          ),
                          _StatusBadge(
                            status: insurance.status,
                            soonText: 'Due soon',
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        insurance.status == statusOverdue
                            ? 'Expired ${formatCnDate(insurance.expiryDate)} · '
                                  '${insurance.daysRemaining.abs()} days ago'
                            : 'Due ${formatCnDate(insurance.expiryDate)} · '
                                  '${insurance.daysRemaining} days left',
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
            const SizedBox(height: 10),
            Text(
              'Local reminder only (visible on this page); your policy is the '
              'authoritative source. Marked "Due soon" within '
              '$insuranceSoonDays days of expiry.',
              style: TextStyle(fontSize: 11, color: palette.textHint),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.past, required this.upcoming});

  final List<InspectionMilestone> past;
  final List<InspectionMilestone> upcoming;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 18, color: palette.primary),
                const SizedBox(width: 6),
                Text(
                  'Inspection timeline',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final milestone in past)
              _TimelineItem(milestone: milestone, isPast: true),
            for (final milestone in upcoming)
              _TimelineItem(milestone: milestone, isPast: false),
            const SizedBox(height: 10),
            Text(
              'Rule: within the first 10 years, only years 6 and 10 require an '
              'in-person inspection — other years just need an inspection '
              'sticker. Marked "Soon" within $dueSoonDays days of the due date.',
              style: TextStyle(fontSize: 11, color: palette.textHint),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.milestone, required this.isPast});

  final InspectionMilestone milestone;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final daysText = isPast
        ? '${milestone.daysRemaining.abs()} days ago'
        : '${milestone.daysRemaining} days left';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPast
                  ? palette.textHint
                  : _statusColor(milestone.status, palette),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Year ${milestone.years} · ${milestone.typeLabel}',
              style: TextStyle(
                fontSize: 13,
                color: isPast ? palette.textHint : palette.onSurface,
              ),
            ),
          ),
          Text(
            isPast ? 'Ignore if already done' : daysText,
            style: TextStyle(
              fontSize: 12,
              color: isPast
                  ? palette.textHint
                  : _statusColor(milestone.status, palette),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({required this.nodes});

  final List<MaintenanceNodeStatus> nodes;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build_rounded, size: 18, color: palette.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'EV maintenance milestones',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final node in nodes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _memoIcon(node.icon),
                        size: 16,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  node.label,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              _StatusBadge(status: node.status),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            node.hint,
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
              ),
            const SizedBox(height: 6),
            Text(
              'Milestones count from the registration date; ignore any already '
              'handled at a service center.',
              style: TextStyle(fontSize: 11, color: palette.textHint),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScienceCard extends StatelessWidget {
  const _ScienceCard();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // 去掉 ExpansionTile 默认分割线
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          dense: true,
          leading: const Icon(
            Icons.menu_book_rounded,
            size: 18,
            color: AppColors.info,
          ),
          title: const Text(
            'Inspection & maintenance basics',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            for (final section in scienceSections)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _memoIcon(section.icon),
                          size: 16,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          section.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    for (final line in section.lines)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '· $line',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SavedMemosCard extends StatelessWidget {
  const _SavedMemosCard({
    required this.memos,
    required this.currentVehicleId,
    required this.onDelete,
  });

  final List<MemoItem> memos;
  final String? currentVehicleId;
  final void Function(String vehicleId) onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved memos · ${memos.length}',
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            for (final memo in memos)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          memo.vehicleName.isEmpty
                              ? 'Unnamed vehicle'
                              : memo.vehicleName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Registered ${memo.registrationDate} · '
                          '${memo.mileageKm} km'
                          '${memo.insuranceExpiryDate == null ? '' : ' · Insured until ${memo.insuranceExpiryDate}'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (memo.vehicleId == currentVehicleId)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        'Current',
                        style: TextStyle(fontSize: 10, color: palette.primary),
                      ),
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: palette.textHint,
                    ),
                    tooltip: 'Delete memo',
                    onPressed: () => onDelete(memo.vehicleId),
                  ),
                ],
              ),
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
