import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/domain/peak_valley_calc.dart';
import 'package:ev_tool_app/core/domain/vehicles.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/features/records/presentation/providers/records_provider.dart';
import 'package:ev_tool_app/features/tools/presentation/widgets/calc_form_widgets.dart';

/* 优化条宽度下限（保证角标可读）与上限（不撑破容器） */
const double _minRatio = 12;
const double _maxRatio = 100;

const int _minutesPerDay = 24 * 60;

final RegExp _timeRe = RegExp(r'^(\d{1,2}):(\d{2})$');

double? _parseNumber(String text) => double.tryParse(text.trim());

/// "08:30" → 510（分钟数）；格式非法返回 null
int? _toMinutes(String time) {
  final match = _timeRe.firstMatch(time);
  if (match == null) return null;
  final hours = int.parse(match.group(1) ?? '0');
  final minutes = int.parse(match.group(2) ?? '0');
  if (hours > 23 || minutes > 59) return null;
  return hours * 60 + minutes;
}

/// 时段时长（分钟），支持跨零点：22:00→08:00 = 600；起止相等视为 0
int? _spanMinutes(String start, String end) {
  final startMin = _toMinutes(start);
  final endMin = _toMinutes(end);
  if (startMin == null || endMin == null) return null;
  if (endMin == startMin) return 0;
  return endMin > startMin
      ? endMin - startMin
      : endMin - startMin + _minutesPerDay;
}

/// 小时段 [hourStart, hourStart+60) 是否与环形时段重叠
bool _hourOverlaps(int hourStart, int spanStart, int spanDuration) {
  for (var i = 0; i < 60; i += 1) {
    final minute = (hourStart + i) % _minutesPerDay;
    final inSpan =
        spanDuration > 0 &&
        ((spanStart + spanDuration <= _minutesPerDay)
            ? (minute >= spanStart && minute < spanStart + spanDuration)
            : (minute >= spanStart ||
                  minute < spanStart + spanDuration - _minutesPerDay));
    if (inSpan) return true;
  }
  return false;
}

/// 24 小时逐时分类（peak / valley / flat）；时段非法返回 null
List<String>? _buildHourlySegments({
  required String peakStart,
  required String peakEnd,
  required String valleyStart,
  required String valleyEnd,
}) {
  final peakSpan = _spanMinutes(peakStart, peakEnd);
  final valleySpan = _spanMinutes(valleyStart, valleyEnd);
  if (peakSpan == null || valleySpan == null) return null;
  if (peakSpan <= 0 || valleySpan <= 0) return null;
  if (peakSpan + valleySpan > _minutesPerDay) return null;
  final peakStartMin = _toMinutes(peakStart);
  final valleyStartMin = _toMinutes(valleyStart);
  if (peakStartMin == null || valleyStartMin == null) return null;

  final segments = <String>[];
  for (var hour = 0; hour < 24; hour += 1) {
    final hourStart = hour * 60;
    final inPeak = _hourOverlaps(hourStart, peakStartMin, peakSpan);
    final inValley = _hourOverlaps(hourStart, valleyStartMin, valleySpan);
    if (inPeak && inValley) return null; // 峰谷重叠
    segments.add(inPeak ? 'peak' : (inValley ? 'valley' : 'flat'));
  }
  return segments;
}

/// 峰谷电价计算页（移植小程序 peak-valley-calc）。
class PeakValleyCalcPage extends ConsumerStatefulWidget {
  const PeakValleyCalcPage({super.key});

  @override
  ConsumerState<PeakValleyCalcPage> createState() => _PeakValleyCalcPageState();
}

class _PeakValleyCalcPageState extends ConsumerState<PeakValleyCalcPage> {
  final _peakPriceController = TextEditingController(text: '1.25');
  final _valleyPriceController = TextEditingController(text: '0.35');
  String _peakStart = '08:00';
  String _peakEnd = '22:00';
  String _valleyStart = '22:00';
  String _valleyEnd = '08:00';
  String _batteryCapacity = '75';
  int _targetPercent = defaultPeakValleyInputs.targetPercent is num
      ? (defaultPeakValleyInputs.targetPercent as num).toInt()
      : 60;
  PeakValleyCost? _result;
  double? _myVehicleBattery;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _result = calcPeakValleyCost(_inputs);
    for (final controller in [_peakPriceController, _valleyPriceController]) {
      controller.addListener(_onPriceChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillVehicle());
  }

  @override
  void dispose() {
    _peakPriceController.dispose();
    _valleyPriceController.dispose();
    super.dispose();
  }

  /* 默认车有电池容量时预填（手动换档可完全覆盖） */
  void _prefillVehicle() {
    if (_initialized || !mounted) return;
    _initialized = true;
    final vehicle = _defaultVehicle(ref.read(vehiclesProvider));
    if (vehicle == null) return;
    setState(() {
      _myVehicleBattery = vehicle.battery;
      _batteryCapacity = formatPlainNumber(vehicle.battery);
    });
    _applyResult();
  }

  Vehicle? _defaultVehicle(List<Vehicle> vehicles) {
    for (final vehicle in vehicles) {
      if (vehicle.isDefault) return vehicle;
    }
    return vehicles.isEmpty ? null : vehicles.first;
  }

  PeakValleyInputs get _inputs => PeakValleyInputs(
    peakStart: _peakStart,
    peakEnd: _peakEnd,
    valleyStart: _valleyStart,
    valleyEnd: _valleyEnd,
    peakPrice: _peakPriceController.text,
    valleyPrice: _valleyPriceController.text,
    batteryCapacity: _batteryCapacity,
    targetPercent: _targetPercent,
  );

  /* 输入非法时只更新字段，保留旧结果避免成本卡闪空 */
  void _setStateWithResult(VoidCallback apply) {
    setState(apply);
    _applyResult();
  }

  void _applyResult() {
    final result = calcPeakValleyCost(_inputs);
    if (result == null) return;
    setState(() => _result = result);
  }

  void _onPriceChanged() {
    if (!mounted) return;
    _applyResult();
  }

  Future<void> _pickTime(String field, String current) async {
    final match = _timeRe.firstMatch(current);
    if (match == null) return;
    final initial = TimeOfDay(
      hour: int.parse(match.group(1) ?? '0'),
      minute: int.parse(match.group(2) ?? '0'),
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final text =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    _setStateWithResult(() {
      switch (field) {
        case 'peakStart':
          _peakStart = text;
        case 'peakEnd':
          _peakEnd = text;
        case 'valleyStart':
          _valleyStart = text;
        case 'valleyEnd':
          _valleyEnd = text;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final result = _result;
    final liveResult = calcPeakValleyCost(_inputs);
    final flatCost = result?.flatCost ?? 0;
    final optimizedCost = result?.optimizedCost ?? 0;
    final saving = result?.saving ?? 0;
    final isWorse = saving < 0;
    final optimizedRatio = flatCost > 0
        ? (optimizedCost / flatCost * 100)
              .round()
              .clamp(_minRatio.toInt(), _maxRatio.toInt())
              .toDouble()
        : _minRatio;

    final segments = _buildHourlySegments(
      peakStart: _peakStart,
      peakEnd: _peakEnd,
      valleyStart: _valleyStart,
      valleyEnd: _valleyEnd,
    );
    final isTimesInvalid = segments == null;

    final peakPrice = _parseNumber(_peakPriceController.text);
    final valleyPrice = _parseNumber(_valleyPriceController.text);
    final hasCheaperValley =
        peakPrice != null && valleyPrice != null && valleyPrice < peakPrice;
    final savingPerKwh = hasCheaperValley ? peakPrice - valleyPrice : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('峰谷电价优化')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            '智能规划充电时间，优化用电成本。',
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          const SizedBox(height: 12),
          CalcCard(
            title: '时段与电价设置',
            icon: Icons.tune,
            iconColor: palette.info,
            child: Column(
              children: [
                _TimePickerRow(
                  dotColor: palette.peak,
                  label: '峰时段 (时:分)',
                  start: _peakStart,
                  end: _peakEnd,
                  onPickStart: () => _pickTime('peakStart', _peakStart),
                  onPickEnd: () => _pickTime('peakEnd', _peakEnd),
                ),
                const SizedBox(height: 12),
                CalcTextField(
                  label: '峰时电价 (¥/度)',
                  hint: '1.25',
                  controller: _peakPriceController,
                ),
                const SizedBox(height: 12),
                _TimePickerRow(
                  dotColor: palette.primary,
                  label: '谷时段 (时:分)',
                  start: _valleyStart,
                  end: _valleyEnd,
                  onPickStart: () => _pickTime('valleyStart', _valleyStart),
                  onPickEnd: () => _pickTime('valleyEnd', _valleyEnd),
                ),
                const SizedBox(height: 12),
                CalcTextField(
                  label: '谷时电价 (¥/度)',
                  hint: '0.35',
                  controller: _valleyPriceController,
                ),
                const SizedBox(height: 12),
                if (isTimesInvalid)
                  Text(
                    '峰谷时段不合法（重叠或时长为 0），请调整',
                    style: TextStyle(fontSize: 12, color: palette.error),
                  )
                else
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 10,
                          child: Row(
                            children: [
                              for (final segment in segments)
                                Expanded(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: switch (segment) {
                                        'peak' => palette.peak,
                                        'valley' => palette.primaryContainer,
                                        _ => palette.surfaceContainerHighest,
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '00:00',
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.textHint,
                            ),
                          ),
                          Text(
                            '24:00',
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.textHint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CalcCard(
            title: '车辆与充电需求',
            icon: Icons.battery_charging_full,
            iconColor: palette.primary,
            child: Column(
              children: [
                _BatteryPickerRow(
                  battery: _batteryCapacity,
                  onTap: () => showBatteryOptionsSheet(
                    context,
                    current: _parseNumber(_batteryCapacity) ?? 0,
                    myVehicleBattery: _myVehicleBattery,
                    onSelect: (capacity) => _setStateWithResult(
                      () => _batteryCapacity = formatPlainNumber(capacity),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '目标充电量',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                    Text(
                      '$_targetPercent%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.onSurface,
                      ),
                    ),
                  ],
                ),
                CalcSlider(
                  value: _targetPercent.toDouble(),
                  min: targetMin.toDouble(),
                  max: targetMax.toDouble(),
                  divisions: (targetMax - targetMin) ~/ 5,
                  onChanged: (value) =>
                      _setStateWithResult(() => _targetPercent = value.round()),
                ),
                const _ScaleRow(left: '$targetMin%', right: '$targetMax%'),
                const SizedBox(height: 4),
                Text(
                  '预计需充入: ${liveResult == null ? '--' : formatPlainNumber(liveResult.energy)} 度电',
                  style: TextStyle(fontSize: 12, color: palette.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CalcCard(
            title: '预估成本对比',
            icon: Icons.bar_chart_rounded,
            iconColor: palette.peak,
            child: Column(
              children: [
                _CostCompareRow(
                  label: '平准电价成本 (按峰谷时长加权)',
                  value: '¥${formatYuan(flatCost)}',
                  valueColor: palette.onSurface,
                  ratio: _maxRatio,
                  barColor: palette.surfaceContainerHighest,
                ),
                const SizedBox(height: 12),
                _CostCompareRow(
                  label: '峰谷优化成本',
                  icon: Icons.eco_outlined,
                  value: '¥${formatYuan(optimizedCost)}',
                  valueColor: palette.primaryContainer,
                  badge: '${isWorse ? '多花' : '省'} ¥${formatYuan(saving.abs())}',
                  ratio: optimizedRatio,
                  barColor: palette.primaryContainer,
                  note: '优化策略：假设全部电量在谷时段充入',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.eco_outlined,
                      size: 14,
                      color: palette.secondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hasCheaperValley
                            ? '建议在谷时段 $_valleyStart - $_valleyEnd 充电，'
                                  '每度省 ¥${formatYuan(savingPerKwh)}'
                            : '当前谷时电价不低于峰时，请核对电价设置',
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const CalcDisclaimer('* 测算结果仅供参考，实际充电费用以电网账单为准。'),
        ],
      ),
    );
  }
}

class _ScaleRow extends StatelessWidget {
  const _ScaleRow({required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: TextStyle(fontSize: 11, color: palette.textHint)),
        Text(right, style: TextStyle(fontSize: 11, color: palette.textHint)),
      ],
    );
  }
}

/// 峰/谷时段选择行：两个时间点 + 中划线。
class _TimePickerRow extends StatelessWidget {
  const _TimePickerRow({
    required this.dotColor,
    required this.label,
    required this.start,
    required this.end,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final Color dotColor;
  final String label;
  final String start;
  final String end;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _TimeBox(value: start, onTap: onPickStart),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('-'),
            ),
            Expanded(
              child: _TimeBox(value: end, onTap: onPickEnd),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.value, this.onTap});

  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: palette.inputBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 14, color: palette.onSurface),
            ),
            Icon(Icons.expand_more_rounded, size: 16, color: palette.textHint),
          ],
        ),
      ),
    );
  }
}

class _BatteryPickerRow extends StatelessWidget {
  const _BatteryPickerRow({required this.battery, this.onTap});

  final String battery;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: palette.inputBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              '电池容量：$battery 度',
              style: TextStyle(fontSize: 13, color: palette.onSurface),
            ),
            const Spacer(),
            Icon(Icons.expand_more_rounded, size: 16, color: palette.textHint),
          ],
        ),
      ),
    );
  }
}

/// 成本对比行：标签 + 金额（可选角标）+ 比例条。
class _CostCompareRow extends StatelessWidget {
  const _CostCompareRow({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.ratio,
    required this.barColor,
    this.icon,
    this.badge,
    this.note,
  });

  final String label;
  final IconData? icon;
  final String value;
  final Color valueColor;
  final String? badge;
  final double ratio;
  final Color barColor;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: palette.secondary),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, color: palette.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          width: double.infinity,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: palette.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: ratio / _maxRatio,
              child: Container(color: barColor, height: 8),
            ),
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(note!, style: TextStyle(fontSize: 11, color: palette.textHint)),
        ],
      ],
    );
  }
}
