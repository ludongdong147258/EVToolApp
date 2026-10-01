/// 续航静态估算（纯函数）
///
/// 根据电池容量、当前 SOC 与百公里电耗算出基准续航，
/// 再按温度 / 路况 / 空调三个工况系数折算出预估续航。
/// 「静态」指不依赖充电记录推导：电耗由用户手动输入，
/// 电池容量可由调用方从默认车辆档案预填。
library;

import 'package:ev_tool_app/core/domain/numbers.dart';

const int batteryMin = 15; // 电池容量下限（kWh，与车辆档案 parseBattery 口径一致）
const int batteryMax = 200; // 电池容量上限（kWh）
const int socMin = 10; // SOC 下限（%）
const int socMax = 100; // SOC 上限（%）
const int consumptionMin = 8; // 百公里电耗下限（kWh/100km）
const int consumptionMax = 30; // 百公里电耗上限（kWh/100km）

/// 工况选项（factor 为续航折扣系数）
class WorkConditionOption {
  const WorkConditionOption({
    required this.value,
    required this.label,
    required this.factor,
  });

  final String value;
  final String label;
  final double factor;
}

/// 温度工况选项
const List<WorkConditionOption> temperatureOptions = [
  WorkConditionOption(value: 'freezing', label: '严寒 ≤-10℃', factor: 0.65),
  WorkConditionOption(value: 'cold', label: '低温 0~10℃', factor: 0.8),
  WorkConditionOption(value: 'mild', label: '常温', factor: 1),
  WorkConditionOption(value: 'hot', label: '高温 ≥35℃', factor: 0.9),
];

/// 路况选项
const List<WorkConditionOption> roadOptions = [
  WorkConditionOption(value: 'city', label: '市区', factor: 1),
  WorkConditionOption(value: 'mixed', label: '综合', factor: 0.9),
  WorkConditionOption(value: 'highway', label: '高速', factor: 0.75),
];

/// 空调选项
const List<WorkConditionOption> acOptions = [
  WorkConditionOption(value: 'off', label: '关闭', factor: 1),
  WorkConditionOption(value: 'on', label: '开启', factor: 0.92),
];

class RangeEstimateInputs {
  const RangeEstimateInputs({
    this.battery = 60, // kWh
    this.soc = 80, // 当前电量 %
    this.consumption = 14, // kWh/100km
    this.temperature = 'mild',
    this.road = 'mixed',
    this.ac = 'off',
  });

  final dynamic battery;
  final dynamic soc;
  final dynamic consumption;
  final String? temperature;
  final String? road;
  final String? ac;

  RangeEstimateInputs copyWith({
    dynamic battery,
    dynamic soc,
    dynamic consumption,
    String? temperature,
    String? road,
    String? ac,
  }) {
    return RangeEstimateInputs(
      battery: battery ?? this.battery,
      soc: soc ?? this.soc,
      consumption: consumption ?? this.consumption,
      temperature: temperature ?? this.temperature,
      road: road ?? this.road,
      ac: ac ?? this.ac,
    );
  }
}

const RangeEstimateInputs defaultRangeInputs = RangeEstimateInputs();

/// JS `inputs || {}` 语义：入参为 null 时视作全字段缺失（而非默认值），
/// 数值字段缺失 → 非法 → 调用方返回 null
const RangeEstimateInputs _emptyInputs = RangeEstimateInputs(
  battery: null,
  soc: null,
  consumption: null,
  temperature: null,
  road: null,
  ac: null,
);

/// 续航估算结果（公里数保留一位小数，系数保留两位）
class RangeEstimateResult {
  const RangeEstimateResult({
    required this.availableEnergy,
    required this.baseRange,
    required this.estimatedRange,
    required this.totalFactor,
  });

  final double availableEnergy;
  final double baseRange;
  final double estimatedRange;
  final double totalFactor;
}

/// 折扣明细单项
class FactorItem {
  const FactorItem({required this.label, required this.factor});

  final String label;
  final double factor;
}

/// 折扣明细：三个工况的选中项与系数，以及综合折扣
class FactorBreakdown {
  const FactorBreakdown({required this.items, required this.total});

  final List<FactorItem> items;
  final double total;
}

/// JS Number.EPSILON（Dart 无内置常量，按 IEEE 754 双精度定义）
const double _numberEpsilon = 2.220446049250313e-16;

/// 保留一位小数（如 342.857 → 342.9；EPSILON 抵御 18.15 → 181.499… 类浮点陷阱）
double _toKm(double value) {
  return ((value + _numberEpsilon) * 10).round() / 10;
}

/// 保留两位小数（折扣系数展示用，如 0.4485 → 0.45）
double _toFactor(double value) {
  return (value * 100).round() / 100;
}

/// 按选项值查选项对象；查不到返回 null
WorkConditionOption? _findOption(
  List<WorkConditionOption> options,
  String? value,
) {
  for (final item in options) {
    if (item.value == value) {
      return item;
    }
  }
  return null;
}

/// 解析后的数值输入
class _NumericInputs {
  const _NumericInputs({
    required this.battery,
    required this.soc,
    required this.consumption,
  });

  final num battery;
  final num soc;
  final num consumption;
}

/// 解析并校验三个数值输入（电池/SOC/电耗）；任一非法返回 null
_NumericInputs? _parseNumericInputs(RangeEstimateInputs source) {
  final battery = toNumber(source.battery);
  final soc = toNumber(source.soc);
  final consumption = toNumber(source.consumption);
  if (battery == null ||
      battery < batteryMin ||
      battery > batteryMax ||
      soc == null ||
      soc < socMin ||
      soc > socMax ||
      consumption == null ||
      consumption < consumptionMin ||
      consumption > consumptionMax) {
    return null;
  }
  return _NumericInputs(battery: battery, soc: soc, consumption: consumption);
}

/// 计算预估续航
///
/// 任一参数非法（非数字 / 越界 / 选项不识别）时返回 null，绝不抛错
RangeEstimateResult? calcRangeEstimate(RangeEstimateInputs? inputs) {
  final source = inputs ?? _emptyInputs;
  final numeric = _parseNumericInputs(source);
  if (numeric == null) {
    return null;
  }

  final pickedOptions = <WorkConditionOption?>[
    _findOption(temperatureOptions, source.temperature),
    _findOption(roadOptions, source.road),
    _findOption(acOptions, source.ac),
  ];
  if (pickedOptions.any((option) => option == null)) {
    return null;
  }
  final factors = pickedOptions.cast<WorkConditionOption>();

  var totalFactor = 1.0;
  for (final option in factors) {
    totalFactor = totalFactor * option.factor;
  }

  final availableEnergy = _toKm((numeric.battery * numeric.soc) / 100);
  final baseRange =
      ((numeric.battery * numeric.soc) / 100 / numeric.consumption) * 100;

  return RangeEstimateResult(
    availableEnergy: availableEnergy,
    baseRange: _toKm(baseRange),
    estimatedRange: _toKm(baseRange * totalFactor),
    totalFactor: _toFactor(totalFactor),
  );
}

/// 折扣明细：三个工况的选中项与系数，以及综合折扣
///
/// 任一输入非法（数值越界 / 选项不识别）时返回 null
FactorBreakdown? getFactorBreakdown(RangeEstimateInputs? inputs) {
  final source = inputs ?? _emptyInputs;
  if (_parseNumericInputs(source) == null) {
    return null;
  }

  final pickedOptions = <WorkConditionOption?>[
    _findOption(temperatureOptions, source.temperature),
    _findOption(roadOptions, source.road),
    _findOption(acOptions, source.ac),
  ];
  if (pickedOptions.any((option) => option == null)) {
    return null;
  }
  final factors = pickedOptions.cast<WorkConditionOption>();

  var total = 1.0;
  for (final option in factors) {
    total = total * option.factor;
  }
  return FactorBreakdown(
    items: [
      for (final option in factors)
        FactorItem(label: option.label, factor: option.factor),
    ],
    total: _toFactor(total),
  );
}
