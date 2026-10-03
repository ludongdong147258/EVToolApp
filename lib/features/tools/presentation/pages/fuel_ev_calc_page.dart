import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/domain/fuel_ev_calc.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/features/tools/presentation/widgets/calc_form_widgets.dart';

/* 电柱最低/最高高度百分比（保证柱内白字可读、且不撑破容器） */
const double _minBarRatio = 45;
const double _maxBarRatio = 100;

const double _barAreaHeight = 150;
const double _barWidth = 96;

/// 油电成本对比页（移植小程序 fuel-ev-calc）。
///
/// 与 JS 的差异：输入框实时重算（JS 为失焦重算），结果口径一致；
/// 输入非法时保留上次有效结果并红框提示。分享链接回流暂不移植。
class FuelEvCalcPage extends StatefulWidget {
  const FuelEvCalcPage({super.key});

  @override
  State<FuelEvCalcPage> createState() => _FuelEvCalcPageState();
}

class _FuelEvCalcPageState extends State<FuelEvCalcPage> {
  int _mileage = defaultMileage;
  final _fuelConsumptionController = TextEditingController(text: '8.5');
  final _fuelPriceController = TextEditingController(text: '8');
  final _evConsumptionController = TextEditingController(text: '15');
  final _elecPriceController = TextEditingController(text: '1.2');
  AnnualCostResult? _result = calcAnnualCost(defaultFuelEvInputs);

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_recompute);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get _controllers => [
    _fuelConsumptionController,
    _fuelPriceController,
    _evConsumptionController,
    _elecPriceController,
  ];

  FuelEvInputs get _inputs => FuelEvInputs(
    mileage: _mileage,
    fuelConsumption: _fuelConsumptionController.text,
    fuelPrice: _fuelPriceController.text,
    evConsumption: _evConsumptionController.text,
    elecPrice: _elecPriceController.text,
  );

  /* 输入变化实时重算；非法时只更新字段，保留旧结果避免图表闪空 */
  void _recompute() {
    final result = calcAnnualCost(_inputs);
    if (result == null) {
      if (mounted) setState(() {});
      return;
    }
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final result = _result;
    final fuelCost = result?.fuelCost ?? 0;
    final evCost = result?.evCost ?? 0;
    final savings = result?.savings ?? 0;
    final savingPer10k = result?.savingPer10k ?? 0;
    final isEvMoreExpensive = savings < 0;
    final evRatio = fuelCost > 0
        ? (evCost / fuelCost * 100)
              .round()
              .clamp(_minBarRatio.toInt(), _maxBarRatio.toInt())
              .toDouble()
        : _minBarRatio;

    return Scaffold(
      appBar: AppBar(title: const Text('Fuel vs EV Cost')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Compare annual running costs of gas vs. electric cars.',
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          const SizedBox(height: 12),
          CalcCard(
            title: 'Annual cost comparison',
            icon: Icons.bar_chart_rounded,
            iconColor: palette.peak,
            child: Column(
              children: [
                SizedBox(
                  height: _barAreaHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _CostBar(
                        value: fuelCost,
                        label: 'Gas car',
                        ratio: _maxBarRatio,
                        color: palette.fuel,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _CostBar(
                        value: evCost,
                        label: 'EV',
                        ratio: evRatio,
                        color: palette.primaryContainer,
                      ),
                    ],
                  ),
                ),
                if (isEvMoreExpensive)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'The EV costs more with these settings',
                      style: TextStyle(fontSize: 12, color: palette.error),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.savings_outlined,
                      size: 20,
                      color: palette.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isEvMoreExpensive ? 'EV costs more' : 'Annual savings',
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatMoney(savings.abs()),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: palette.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${isEvMoreExpensive ? 'Costs' : 'Saves'} '
                  '${formatMoney(savingPer10k.abs())} per 10,000 km',
                  style: TextStyle(fontSize: 12, color: palette.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CalcCard(
            title: 'Driving profile',
            icon: Icons.tune,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Annual mileage',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                    Text(
                      '${formatAmount(_mileage)} km',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.onSurface,
                      ),
                    ),
                  ],
                ),
                CalcSlider(
                  value: _mileage.toDouble(),
                  min: minMileage.toDouble(),
                  max: maxMileage.toDouble(),
                  divisions: (maxMileage - minMileage) ~/ 1000,
                  onChanged: (value) {
                    setState(() => _mileage = value.round());
                    _recompute();
                  },
                ),
                SliderScaleRow(
                  start: formatAmount(minMileage),
                  end: formatAmount(maxMileage),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CalcCard(
            title: 'Gas car',
            icon: Icons.local_gas_station,
            iconColor: palette.fuel,
            child: Column(
              children: [
                CalcTextField(
                  label: 'Fuel consumption (L/100km)',
                  hint: '8.5',
                  controller: _fuelConsumptionController,
                ),
                const SizedBox(height: 12),
                CalcTextField(
                  label: 'Fuel price (\$/L)',
                  hint: '8.0',
                  controller: _fuelPriceController,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CalcCard(
            title: 'EV',
            icon: Icons.bolt_rounded,
            iconColor: palette.primaryContainer,
            child: Column(
              children: [
                CalcTextField(
                  label: 'Energy consumption (kWh/100km)',
                  hint: '15.0',
                  controller: _evConsumptionController,
                ),
                const SizedBox(height: 12),
                CalcTextField(
                  label: 'Electricity price (\$/kWh)',
                  hint: '1.2',
                  controller: _elecPriceController,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 单根成本柱：底部对齐，高度按 ratio 百分比，柱内白字金额。
class _CostBar extends StatelessWidget {
  const _CostBar({
    required this.value,
    required this.label,
    required this.ratio,
    required this.color,
  });

  final int value;
  final String label;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: _barWidth,
      height: _barAreaHeight,
      child: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: 1,
                heightFactor: ratio / _maxBarRatio,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppColors.radiusSm),
                    ),
                  ),
                  child: Text(
                    formatMoney(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
