import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/range_estimate.dart';
import 'package:ev_tool_app/core/domain/vehicles.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/gradient_hero_card.dart';
import 'package:ev_tool_app/features/records/presentation/providers/records_provider.dart';
import 'package:ev_tool_app/features/tools/presentation/widgets/calc_form_widgets.dart';

/* 常见百公里电耗预设（kWh/100km）：紧凑级省电 → 大型/SUV 费电 */
const List<int> _consumptionPresets = <int>[12, 14, 16, 18, 20];

double? _parseNumber(String text) => double.tryParse(text.trim());

/// 续航静态估算页（移植小程序 range-calc）。
class RangeCalcPage extends ConsumerStatefulWidget {
  const RangeCalcPage({super.key});

  @override
  ConsumerState<RangeCalcPage> createState() => _RangeCalcPageState();
}

class _RangeCalcPageState extends ConsumerState<RangeCalcPage> {
  final _consumptionController = TextEditingController(text: '14');
  String _battery = '60';
  int _soc = 80;
  String _temperature = defaultRangeInputs.temperature ?? 'mild';
  String _road = defaultRangeInputs.road ?? 'mixed';
  String _ac = defaultRangeInputs.ac ?? 'off';
  RangeEstimateResult? _result = calcRangeEstimate(defaultRangeInputs);
  FactorBreakdown? _breakdown = getFactorBreakdown(defaultRangeInputs);
  double? _myVehicleBattery;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _consumptionController.addListener(_onConsumptionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillVehicle());
  }

  @override
  void dispose() {
    _consumptionController.dispose();
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
      _battery = formatPlainNumber(vehicle.battery);
    });
    _applyResult();
  }

  Vehicle? _defaultVehicle(List<Vehicle> vehicles) {
    for (final vehicle in vehicles) {
      if (vehicle.isDefault) return vehicle;
    }
    return vehicles.isEmpty ? null : vehicles.first;
  }

  RangeEstimateInputs get _inputs => RangeEstimateInputs(
    battery: _battery,
    soc: _soc,
    consumption: _consumptionController.text,
    temperature: _temperature,
    road: _road,
    ac: _ac,
  );

  /* 输入非法时只更新字段，保留旧结果/旧明细避免结果卡闪空 */
  void _setStateWithResult(VoidCallback apply) {
    setState(apply);
    _applyResult();
  }

  void _applyResult() {
    final result = calcRangeEstimate(_inputs);
    if (result == null) return;
    setState(() {
      _result = result;
      _breakdown = getFactorBreakdown(_inputs);
    });
  }

  void _onConsumptionChanged() {
    if (!mounted) return;
    _applyResult();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final result = _result;
    final breakdown = _breakdown;
    final liveResult = calcRangeEstimate(_inputs);

    return Scaffold(
      appBar: AppBar(title: const Text('续航静态估算')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            '基于电池容量与电耗，预估当前电量可行驶里程。',
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          const SizedBox(height: 12),
          GradientHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.insights_outlined,
                      size: 14,
                      color: AppColors.onPrimaryA85,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '预估续航',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onPrimaryA85,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: formatPlainNumber(result?.estimatedRange ?? 0),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const TextSpan(
                        text: ' km',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.onPrimaryA85,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _HeroDetailLine(
                  icon: Icons.bolt_rounded,
                  label: '可用电量',
                  value:
                      '${formatPlainNumber(result?.availableEnergy ?? 0)} kWh',
                ),
                _HeroDetailLine(
                  icon: Icons.speed,
                  label: '基准续航',
                  value: '${formatPlainNumber(result?.baseRange ?? 0)} km',
                ),
                for (final item in breakdown?.items ?? const <FactorItem>[])
                  _HeroDetailLine(
                    icon: Icons.thermostat,
                    label: item.label,
                    value: '×${item.factor}',
                  ),
                _HeroDetailLine(
                  icon: Icons.tune,
                  label: '综合折扣',
                  value: formatDiscount(result?.totalFactor ?? 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CalcCard(
            title: '车辆与当前电量',
            icon: Icons.battery_charging_full,
            iconColor: palette.primary,
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  onTap: () => showBatteryOptionsSheet(
                    context,
                    current: _parseNumber(_battery) ?? 0,
                    myVehicleBattery: _myVehicleBattery,
                    onSelect: (capacity) => _setStateWithResult(
                      () => _battery = formatPlainNumber(capacity),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: palette.inputBg,
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '电池容量：$_battery 度',
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.onSurface,
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
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '当前电量',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                    Text(
                      '$_soc%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.onSurface,
                      ),
                    ),
                  ],
                ),
                CalcSlider(
                  value: _soc.toDouble(),
                  min: socMin.toDouble(),
                  max: socMax.toDouble(),
                  divisions: (socMax - socMin) ~/ 5,
                  onChanged: (value) =>
                      _setStateWithResult(() => _soc = value.round()),
                ),
                const SliderScaleRow(start: '$socMin%', end: '$socMax%'),
                const SizedBox(height: 4),
                Text(
                  '可用电量: ${liveResult == null ? '--' : formatPlainNumber(liveResult.availableEnergy)} 度电',
                  style: TextStyle(fontSize: 12, color: palette.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CalcCard(
            title: '电耗与工况',
            icon: Icons.speed,
            iconColor: palette.info,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CalcTextField(
                  label: '百公里电耗 (kWh/100km)',
                  hint: '14',
                  controller: _consumptionController,
                ),
                const SizedBox(height: 4),
                Text(
                  '建议填车机标称 / 工信部电耗（如 14）；填实测电耗时请选常温 / 市区 / 关闭，避免重复折扣',
                  style: TextStyle(fontSize: 11, color: palette.textHint),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in _consumptionPresets)
                      CalcChip(
                        label: '$preset',
                        isSelected:
                            _parseNumber(_consumptionController.text) == preset,
                        onTap: () => _setStateWithResult(
                          () => _consumptionController.text = '$preset',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _ConditionChips(
                  label: '温度',
                  options: temperatureOptions,
                  current: _temperature,
                  onSelect: (value) =>
                      _setStateWithResult(() => _temperature = value),
                ),
                const SizedBox(height: 12),
                _ConditionChips(
                  label: '路况',
                  options: roadOptions,
                  current: _road,
                  onSelect: (value) => _setStateWithResult(() => _road = value),
                ),
                const SizedBox(height: 12),
                _ConditionChips(
                  label: '空调',
                  options: acOptions,
                  current: _ac,
                  onSelect: (value) => _setStateWithResult(() => _ac = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const CalcDisclaimer(
            '* 测算结果仅供参考：电耗按标称口径估算，实际续航受驾驶习惯、载重、电池可用容量等因素影响。',
          ),
        ],
      ),
    );
  }
}

/// 工况单选 chips（温度 / 路况 / 空调共用），chip 内显示系数小字。
class _ConditionChips extends StatelessWidget {
  const _ConditionChips({
    required this.label,
    required this.options,
    required this.current,
    required this.onSelect,
  });

  final String label;
  final List<WorkConditionOption> options;
  final String current;
  final ValueChanged<String> onSelect;

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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              CalcChip(
                label: option.label,
                sublabel: '×${option.factor}',
                isSelected: current == option.value,
                onTap: () => onSelect(option.value),
              ),
          ],
        ),
      ],
    );
  }
}

/// Hero 结果卡明细行（图标 + 标签 + 右侧数值）。
class _HeroDetailLine extends StatelessWidget {
  const _HeroDetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.onPrimaryA85),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.onPrimaryA85,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
