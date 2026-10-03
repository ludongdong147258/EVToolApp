import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:ev_tool_app/core/domain/charge_map.dart' show findNearestCity;
import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/routing/route_names.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/utils/coord_convert.dart';
import 'package:ev_tool_app/core/widgets/app_primary_button.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart' show showAppToast;
import 'package:ev_tool_app/core/domain/ocr_receipt.dart';
import 'package:ev_tool_app/features/maps/presentation/pages/location_picker_page.dart';
import 'package:ev_tool_app/features/ocr/presentation/widgets/ocr_entry_card.dart';
import 'package:ev_tool_app/features/records/data/repositories/draft_repository.dart';
import 'package:ev_tool_app/features/records/presentation/providers/records_provider.dart';
import 'package:ev_tool_app/features/stations/data/station_repository.dart';

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
  final _ocrKey = GlobalKey<OcrEntryCardState>();
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
  double? _latitude;
  double? _longitude;
  Timer? _draftTimer;
  bool _initialized = false;

  /// 小票识别行内错误文案（null = 无错误；重试入口随其显示）。
  String? _ocrError;

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
        _latitude = record.latitude;
        _longitude = record.longitude;
      });
      return;
    }
    // 先走草稿恢复（可能弹询问框），结束后再自动定位，避免弹窗竞争
    _offerRestoreDraft().then((_) => _autoLocate());
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
      _vehicleId =
          form.vehicleId is String && (form.vehicleId as String).isNotEmpty
          ? form.vehicleId as String
          : null;
      _vehicleName = form.vehicleName is String
          ? form.vehicleName as String?
          : null;
      _province = form.province is String ? form.province as String? : null;
      _city = form.city is String ? form.city as String? : null;
      _locationName = form.locationName is String
          ? form.locationName as String?
          : null;
      _latitude = form.latitude is num
          ? (form.latitude as num).toDouble()
          : null;
      _longitude = form.longitude is num
          ? (form.longitude as num).toDouble()
          : null;
    });
  }

  /// 进页自动定位当前所在位置（对齐小程序 silentLocateIfAuthorized）：
  /// 新增模式专用；系统授权弹窗只在首次进入时出现一次，拒绝后静默不打扰。
  /// 全程异常吞掉 —— 定位失败不影响手动选点。
  Future<void> _autoLocate() async {
    if (!mounted) return;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final granted =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      if (!granted || !mounted) return;

      final position = await Geolocator.getCurrentPosition();
      // iOS 返回 WGS-84，地图与逆地理均为 GCJ-02，需转换
      final gcj = wgs84ToGcj02(position.latitude, position.longitude);
      if (!mounted) return;

      // 竞态守卫：用户已手动选点（或恢复了含地点的草稿）则不覆盖
      if (_latitude != null || _city != null) return;

      String? province;
      String? city;
      String? locationName;
      try {
        final region = await ref
            .read(stationRepositoryProvider)
            .reverseGeocode(gcj.latitude, gcj.longitude);
        province = region.province;
        city = region.city.isNotEmpty ? region.city : null;
        final title = region.poiTitle.isNotEmpty
            ? region.poiTitle
            : region.address;
        locationName = title.length > locationNameMaxLength
            ? title.substring(0, locationNameMaxLength)
            : (title.isEmpty ? null : title);
      } on Exception {
        // 逆地理失败降级：本地城市坐标库取最近城市
        final nearest = findNearestCity(gcj.latitude, gcj.longitude);
        province = nearest?.province;
        city = nearest?.city;
      }
      if (!mounted) return;
      setState(() {
        _province = province;
        _city = city;
        _locationName = locationName;
        _latitude = gcj.latitude;
        _longitude = gcj.longitude;
      });
    } on Exception {
      // 定位不可用（模拟器/未授权/插件异常）静默跳过
    }
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

  /// OCR 识别结果回填表单（对齐小程序 applyReceiptResult：
  /// 覆盖用户已填项前弹确认；备注只在为空时回填；成功 toast + 轻震动）。
  Future<void> _applyReceiptResult(ReceiptResult result) async {
    final filled = result.filledFields.toSet();
    final parsedDate = DateTime.tryParse(result.date);
    final hasDate = parsedDate != null && !parsedDate.isAfter(DateTime.now());
    final hasDuration = result.hours.isNotEmpty || result.minutes.isNotEmpty;
    final hasType = result.chargeType == 'fast' || result.chargeType == 'home';
    final noteEmpty = _noteController.text.isEmpty && result.note.isNotEmpty;

    // 统计将被覆盖的用户已填项
    final now = DateTime.now();
    final isToday =
        _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
    var overwritten = 0;
    if (filled.contains('cost') && _costController.text.trim().isNotEmpty) {
      overwritten++;
    }
    if (filled.contains('energy') && _energyController.text.trim().isNotEmpty) {
      overwritten++;
    }
    if (filled.contains('duration') &&
        (_hoursController.text.trim().isNotEmpty ||
            _minutesController.text.trim().isNotEmpty)) {
      overwritten++;
    }
    if (filled.contains('date') && hasDate && !isToday) {
      overwritten++;
    }
    if (filled.contains('chargeType') &&
        hasType &&
        _type != result.chargeType) {
      overwritten++;
    }
    if (overwritten > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('覆盖确认'),
          content: Text('识别结果将覆盖已填写的 $overwritten 项内容，是否继续？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('继续'),
            ),
          ],
        ),
      );
      if (proceed != true) {
        return; // 取消：丢弃识别结果，保留用户手填内容
      }
    }

    var count = 0;
    setState(() {
      if (result.cost.isNotEmpty) {
        _costController.text = result.cost;
        count++;
      }
      if (result.energy.isNotEmpty) {
        _energyController.text = result.energy;
        count++;
      }
      if (hasDuration) {
        if (result.hours.isNotEmpty) _hoursController.text = result.hours;
        if (result.minutes.isNotEmpty) {
          _minutesController.text = result.minutes;
        }
        count++;
      }
      if (hasDate) {
        _date = parsedDate;
        count++;
      }
      if (hasType) {
        _type = result.chargeType;
        count++;
      }
      if (noteEmpty) {
        _noteController.text = result.note;
        count++;
      }
      _ocrError = null;
    });
    if (count == 0 || !mounted) {
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    const receiptFieldGroupCount = 6;
    showAppToast(
      context,
      count < receiptFieldGroupCount
          ? '已识别 $count 项，其余请手动补填'
          : '已识别 $count 项，请核对',
    );
  }

  /// 行内错误重试：重新拉起小票识别选图。
  void _retryOcr() {
    _ocrKey.currentState?.openPicker();
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
    latitude: _latitude,
    longitude: _longitude,
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

  /// 地图选点：打开选点页，返回后回填省市/地点名/坐标。
  Future<void> _pickLocation() async {
    final picked = await context.push<PickedLocation>(
      RouteNames.locationPicker,
      extra: (_latitude != null && _longitude != null)
          ? PickedLocation(latitude: _latitude!, longitude: _longitude!)
          : null,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _province = picked.province;
      _city = picked.city;
      _locationName = picked.locationName;
      _latitude = picked.latitude;
      _longitude = picked.longitude;
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
            _FormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 小票识别入口（Key 缺失自隐藏；错误行内反馈 + 重试）
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: OcrEntryCard(
                      key: _ocrKey,
                      onResult: (result) =>
                          unawaited(_applyReceiptResult(result)),
                      onError: (message) => setState(
                        () => _ocrError = message.isEmpty ? null : message,
                      ),
                    ),
                  ),
                  if (_ocrError != null) ...[
                    const SizedBox(height: 4),
                    _OcrErrorRow(
                      message: _ocrError!,
                      onRetry: () => _retryOcr(),
                    ),
                  ],
                  if (_ocrError != null) const SizedBox(height: 16),
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
                        : '点击地图选择地点',
                    icon: Icons.place_rounded,
                    onTap: _pickLocation,
                    trailing:
                        (_city != null ||
                            _locationName != null ||
                            _latitude != null)
                        ? GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() {
                              _province = null;
                              _city = null;
                              _locationName = null;
                              _latitude = null;
                              _longitude = null;
                            }),
                            child: const SizedBox(
                              width: 24,
                              height: 20,
                              child: Center(child: Icon(Icons.close, size: 16)),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _NumberField(
                    label: '备注（选填，最多 100 字）',
                    hint: '如：家充为主、夜间谷电',
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
        constraints: const BoxConstraints(minHeight: 48),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
        _FieldLabel(label),
        TextField(
          controller: controller,
          keyboardType: isMultiline
              ? TextInputType.multiline
              : (allowDecimal
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.number),
          // 多行备注：文本无数字过滤，限 100 字（label 口径）；计数条已隐藏
          maxLength: isMultiline ? 100 : maxDigits,
          // 备注与养车支出备注框同高：空态即 3 行固定高度
          maxLines: isMultiline ? 3 : 1,
          minLines: isMultiline ? 3 : 1,
          inputFormatters: [
            if (!isMultiline)
              FilteringTextInputFormatter.allow(
                allowDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
              ),
          ],
          // 单行数字输入收紧内边距；多行备注与养车支出备注框同高（走全局主题内边距）
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            isDense: !isMultiline,
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

/// 小票识别行内错误行：红字文案 + 「重试」文字按钮（对齐小程序 .ocr-error-row）。
class _OcrErrorRow extends StatelessWidget {
  const _OcrErrorRow({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: TextStyle(fontSize: 11, color: palette.error),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onRetry,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '重试',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.primaryContainer,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
