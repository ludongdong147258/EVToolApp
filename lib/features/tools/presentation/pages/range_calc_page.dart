import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/range_estimate.dart';
import 'package:ev_tool_app/core/domain/vehicles.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/gradient_hero_card.dart';
import 'package:ev_tool_app/features/records/presentation/providers/records_provider.dart';
import 'package:ev_tool_app/features/tools/presentation/widgets/calc_form_widgets.dart';

/* 常见能效预设（mi/kWh）：紧凑级省电 → 大型/SUV 费电 */
const List<double> _efficiencyPresets = <double>[2.5, 3.0, 3.4, 4.0, 4.5];

double? _parseNumber(String text) => double.tryParse(text.trim());

/// 续航静态估算页（移植小程序 range-calc）。
class RangeCalcPage extends ConsumerStatefulWidget {
  const RangeCalcPage({super.key});

  @override
  ConsumerState<RangeCalcPage> createState() => _RangeCalcPageState();
}

class _RangeCalcPageState extends ConsumerState<RangeCalcPage> {
  final _efficiencyController = TextEditingController(text: '3.4');
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
    _efficiencyController.addListener(_onEfficiencyChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillVehicle());
  }

  @override
  void dispose() {
    _efficiencyController.dispose();
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
    efficiency: _efficiencyController.text,
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

  void _onEfficiencyChanged() {
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
      appBar: AppBar(title: const Text('Range Estimate')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Estimate how far you can go on the current charge.',
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
                      'Estimated range',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.onPrimaryA85,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: formatPlainNumber(result?.estimatedRange ?? 0),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const TextSpan(
                        text: ' mi',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.onPrimaryA85,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 明细列表顶部分隔线（对齐小程序 .re-detail-list）
                Container(height: 1, color: AppColors.onPrimaryA28),
                const SizedBox(height: 8),
                _HeroDetailLine(
                  icon: Icons.bolt_rounded,
                  label: 'Available energy',
                  value:
                      '${formatPlainNumber(result?.availableEnergy ?? 0)} kWh',
                ),
                _HeroDetailLine(
                  icon: Icons.speed,
                  label: 'Base range',
                  value: '${formatPlainNumber(result?.baseRange ?? 0)} mi',
                ),
                // 工况系数行图标按序对应 温度/路况/空调
                for (final (index, item)
                    in (breakdown?.items ?? const <FactorItem>[]).indexed)
                  _HeroDetailLine(
                    icon: switch (index) {
                      0 => Icons.thermostat,
                      1 => Icons.directions_car_rounded,
                      _ => Icons.eco_rounded,
                    },
                    label: item.label,
                    value: '×${item.factor}',
                  ),
                _HeroDetailLine(
                  icon: Icons.tune,
                  label: 'Overall factor',
                  value: formatDiscount(result?.totalFactor ?? 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CalcCard(
            title: 'Vehicle & charge',
            icon: Icons.battery_charging_full,
            iconColor: palette.primary,
            child: Column(
              children: [
                // 电池容量通栏行 + 底部分割线（对齐小程序 .re-battery-row）
                InkWell(
                  onTap: () => showBatteryOptionsSheet(
                    context,
                    current: _parseNumber(_battery) ?? 0,
                    myVehicleBattery: _myVehicleBattery,
                    onSelect: (capacity) => _setStateWithResult(
                      () => _battery = formatPlainNumber(capacity),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: palette.divider, width: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Battery capacity (kWh)',
                          style: TextStyle(
                            fontSize: 14,
                            color: palette.onSurface,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _battery,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: palette.onSurface,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'kWh',
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                            Icon(
                              Icons.expand_more_rounded,
                              size: 16,
                              color: palette.textHint,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current charge',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                    // 数值用品牌色（对齐小程序 .re-target-value）
                    Text(
                      '$_soc%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: palette.primary,
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
                  'Available energy: ${liveResult == null ? '--' : formatPlainNumber(liveResult.availableEnergy)} kWh',
                  style: TextStyle(fontSize: 12, color: palette.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CalcCard(
            title: 'Efficiency & conditions',
            icon: Icons.speed,
            iconColor: palette.info,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CalcTextField(
                  label: 'Efficiency (mi/kWh)',
                  hint: '3.4',
                  controller: _efficiencyController,
                ),
                const SizedBox(height: 4),
                Text(
                  'Use the rated value from your car (e.g. 3.4); if you enter a real-world figure, pick Mild / City / Off to avoid double discounts',
                  style: TextStyle(fontSize: 11, color: palette.textHint),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in _efficiencyPresets)
                      CalcChip(
                        label: formatPlainNumber(preset),
                        isSelected:
                            _parseNumber(_efficiencyController.text) == preset,
                        onTap: () => _setStateWithResult(
                          () => _efficiencyController.text = formatPlainNumber(
                            preset,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _ConditionChips(
                  label: 'Temperature',
                  options: temperatureOptions,
                  current: _temperature,
                  onSelect: (value) =>
                      _setStateWithResult(() => _temperature = value),
                ),
                const SizedBox(height: 12),
                _ConditionChips(
                  label: 'Road',
                  inline: true,
                  options: roadOptions,
                  current: _road,
                  onSelect: (value) => _setStateWithResult(() => _road = value),
                ),
                const SizedBox(height: 12),
                _ConditionChips(
                  label: 'A/C',
                  inline: true,
                  options: acOptions,
                  current: _ac,
                  onSelect: (value) => _setStateWithResult(() => _ac = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const CalcDisclaimer(
            '* Estimates only: based on rated efficiency; actual range depends on driving style, load, usable capacity, and more.',
          ),
        ],
      ),
    );
  }
}

/// 工况单选 chips（温度 / 路况 / 空调共用），chip 内显示系数小字；
/// [inline] 时 label 与 chips 同行（对齐小程序 路况/空调 布局）。
class _ConditionChips extends StatelessWidget {
  const _ConditionChips({
    required this.label,
    required this.options,
    required this.current,
    required this.onSelect,
    this.inline = false,
  });

  final String label;
  final List<WorkConditionOption> options;
  final String current;
  final ValueChanged<String> onSelect;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final labelWidget = Text(
      label,
      style: TextStyle(fontSize: 12, color: palette.textSecondary),
    );
    final chips = [
      for (final option in options)
        CalcChip(
          label: option.label,
          sublabel: '×${option.factor}',
          isSelected: current == option.value,
          onTap: () => onSelect(option.value),
        ),
    ];
    if (inline) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(padding: const EdgeInsets.only(right: 4), child: labelWidget),
          ...chips,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labelWidget,
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
