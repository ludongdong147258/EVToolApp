/// 油电成本计算（纯函数）
///
/// 根据年行驶里程、燃油车参数（油耗/油价）与电动车参数（电耗/电价），
/// 计算两者的年度用车成本、节省金额与每万公里节省。
library;

import 'package:ev_tool_app/core/domain/numbers.dart';

const int minMileage = 1000;
const int maxMileage = 200000;
const int defaultMileage = 15000;

/// 默认输入（数值字段可为 number 或字符串，与输入框对接）
class FuelEvInputs {
  const FuelEvInputs({
    this.mileage = defaultMileage,
    this.fuelConsumption = 8.5,
    this.fuelPrice = 8.0,
    this.evConsumption = 15.0,
    this.elecPrice = 1.2,
  });

  final dynamic mileage; // 年行驶里程 km
  final dynamic fuelConsumption; // 油耗 L/100km
  final dynamic fuelPrice; // 油价 ¥/L
  final dynamic evConsumption; // 电耗 kWh/100km
  final dynamic elecPrice; // 电价 ¥/kWh

  FuelEvInputs copyWith({
    dynamic mileage,
    dynamic fuelConsumption,
    dynamic fuelPrice,
    dynamic evConsumption,
    dynamic elecPrice,
  }) {
    return FuelEvInputs(
      mileage: mileage ?? this.mileage,
      fuelConsumption: fuelConsumption ?? this.fuelConsumption,
      fuelPrice: fuelPrice ?? this.fuelPrice,
      evConsumption: evConsumption ?? this.evConsumption,
      elecPrice: elecPrice ?? this.elecPrice,
    );
  }
}

const FuelEvInputs defaultFuelEvInputs = FuelEvInputs();

/// 年度成本对比结果（整数元）
class AnnualCostResult {
  const AnnualCostResult({
    required this.fuelCost,
    required this.evCost,
    required this.savings,
    required this.savingPer10k,
  });

  final int fuelCost;
  final int evCost;
  final int savings;
  final int savingPer10k;
}

/// 计算年度成本对比；任一参数非法（非数字或 ≤ 0）时返回 null
AnnualCostResult? calcAnnualCost(FuelEvInputs inputs) {
  final mileage = toNumber(inputs.mileage);
  final fuelConsumption = toNumber(inputs.fuelConsumption);
  final fuelPrice = toNumber(inputs.fuelPrice);
  final evConsumption = toNumber(inputs.evConsumption);
  final elecPrice = toNumber(inputs.elecPrice);

  if (mileage == null ||
      fuelConsumption == null ||
      fuelPrice == null ||
      evConsumption == null ||
      elecPrice == null) {
    return null;
  }
  final values = <num>[
    mileage,
    fuelConsumption,
    fuelPrice,
    evConsumption,
    elecPrice,
  ];
  if (values.any((v) => v <= 0)) {
    return null;
  }

  final fuelCost = ((mileage / 100) * fuelConsumption * fuelPrice).round();
  final evCost = ((mileage / 100) * evConsumption * elecPrice).round();
  final savings = fuelCost - evCost;

  return AnnualCostResult(
    fuelCost: fuelCost,
    evCost: evCost,
    savings: savings,
    savingPer10k: ((savings / mileage) * 10000).round(),
  );
}

/// 分享参数短键：控制转发 path 长度（顺序即编码顺序）
const Map<String, String> _shareKeys = {
  'mileage': 'm',
  'fuelConsumption': 'fc',
  'fuelPrice': 'fp',
  'evConsumption': 'ec',
  'elecPrice': 'ep',
};

/// JS `String(number)` 语义：整数值不带小数点（8.0 → "8"）
String _numToStr(num value) {
  if (value is int) {
    return value.toString();
  }
  final d = value.toDouble();
  if (d == d.truncateToDouble()) {
    return d.truncate().toString();
  }
  return d.toString();
}

/// 把计算输入编码为分享 path 的 query 串
///
/// 如 "m=15000&fc=8.5&fp=8&ec=15&ep=1.2"；非法值跳过，全部非法返回 ""
String buildShareQuery(FuelEvInputs inputs) {
  final parts = <String>[];
  for (final field in _shareKeys.keys) {
    final dynamic raw = _fieldOf(inputs, field);
    final num? numValue = toNumber(raw);
    if (numValue == null || numValue <= 0) {
      continue;
    }
    parts.add(
      '${_shareKeys[field]}=${Uri.encodeComponent(_numToStr(numValue))}',
    );
  }
  return parts.join('&');
}

dynamic _fieldOf(FuelEvInputs inputs, String field) {
  switch (field) {
    case 'mileage':
      return inputs.mileage;
    case 'fuelConsumption':
      return inputs.fuelConsumption;
    case 'fuelPrice':
      return inputs.fuelPrice;
    case 'evConsumption':
      return inputs.evConsumption;
    case 'elecPrice':
      return inputs.elecPrice;
  }
  return null;
}

/// 从路由 params 解析分享输入（buildShareQuery 的逆操作）
///
/// 返回可直接供 calcAnnualCost 消费的字符串输入；缺参或非法返回 null
FuelEvInputs? parseShareQuery(Map<String, String>? params) {
  if (params == null) {
    return null;
  }
  var mileage = '';
  var fuelConsumption = '';
  var fuelPrice = '';
  var evConsumption = '';
  var elecPrice = '';
  for (final entry in _shareKeys.entries) {
    final raw = params[entry.value];
    final numValue = toNumber(raw);
    if (numValue == null || numValue <= 0) {
      return null;
    }
    final text = _numToStr(numValue);
    switch (entry.key) {
      case 'mileage':
        mileage = text;
      case 'fuelConsumption':
        fuelConsumption = text;
      case 'fuelPrice':
        fuelPrice = text;
      case 'evConsumption':
        evConsumption = text;
      case 'elecPrice':
        elecPrice = text;
    }
  }
  return FuelEvInputs(
    mileage: mileage,
    fuelConsumption: fuelConsumption,
    fuelPrice: fuelPrice,
    evConsumption: evConsumption,
    elecPrice: elecPrice,
  );
}

/// 生成带结果数字的动态分享标题
///
/// 节省为正 → 省钱口径；为负 → 差额口径；空 → 兜底文案
String buildShareTitle(AnnualCostResult? result) {
  if (result == null) {
    return '油电成本对比 · 一分钟算出开电车能省多少';
  }
  if (result.savings > 0) {
    return '开电车一年比油车省 ¥${formatAmount(result.savings)}，帮你算好了';
  }
  return '油电一年成本差 ¥${formatAmount(result.savings.abs())}，进来算算你的';
}
