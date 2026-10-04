/// 油电成本计算（纯函数，美制单位）
///
/// 根据年行驶里程、燃油车参数（MPG/油价 $/gal）与电动车参数
/// （效率 mi/kWh/电价 $/kWh），计算两者的年度用车成本、节省金额
/// 与每万英里节省。
library;

import 'package:ev_tool_app/core/domain/numbers.dart';

const int minMileage = 500;
const int maxMileage = 100000;
const int defaultMileage = 13500;

/// 默认输入（数值字段可为 number 或字符串，与输入框对接）
class FuelEvInputs {
  const FuelEvInputs({
    this.mileage = defaultMileage,
    this.mpg = 28,
    this.gasPrice = 3.3,
    this.miPerKwh = 3.3,
    this.elecPrice = 0.16,
  });

  final dynamic mileage; // 年行驶里程 mi
  final dynamic mpg; // 燃油经济性 MPG
  final dynamic gasPrice; // 油价 $/gal
  final dynamic miPerKwh; // 电动车效率 mi/kWh
  final dynamic elecPrice; // 电价 $/kWh

  FuelEvInputs copyWith({
    dynamic mileage,
    dynamic mpg,
    dynamic gasPrice,
    dynamic miPerKwh,
    dynamic elecPrice,
  }) {
    return FuelEvInputs(
      mileage: mileage ?? this.mileage,
      mpg: mpg ?? this.mpg,
      gasPrice: gasPrice ?? this.gasPrice,
      miPerKwh: miPerKwh ?? this.miPerKwh,
      elecPrice: elecPrice ?? this.elecPrice,
    );
  }
}

const FuelEvInputs defaultFuelEvInputs = FuelEvInputs();

/// 年度成本对比结果（整数美元）
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
  final mpg = toNumber(inputs.mpg);
  final gasPrice = toNumber(inputs.gasPrice);
  final miPerKwh = toNumber(inputs.miPerKwh);
  final elecPrice = toNumber(inputs.elecPrice);

  if (mileage == null ||
      mpg == null ||
      gasPrice == null ||
      miPerKwh == null ||
      elecPrice == null) {
    return null;
  }
  final values = <num>[mileage, mpg, gasPrice, miPerKwh, elecPrice];
  if (values.any((v) => v <= 0)) {
    return null;
  }

  final fuelCost = (mileage / mpg * gasPrice).round();
  final evCost = (mileage / miPerKwh * elecPrice).round();
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
  'mpg': 'fc',
  'gasPrice': 'fp',
  'miPerKwh': 'ec',
  'elecPrice': 'ep',
};

/// JS `String(number)` 语义：整数值不带小数点（3.0 → "3"）
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
/// 如 "m=13500&fc=28&fp=3.3&ec=3.3&ep=0.16"；非法值跳过，全部非法返回 ""
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
    case 'mpg':
      return inputs.mpg;
    case 'gasPrice':
      return inputs.gasPrice;
    case 'miPerKwh':
      return inputs.miPerKwh;
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
  var mpg = '';
  var gasPrice = '';
  var miPerKwh = '';
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
      case 'mpg':
        mpg = text;
      case 'gasPrice':
        gasPrice = text;
      case 'miPerKwh':
        miPerKwh = text;
      case 'elecPrice':
        elecPrice = text;
    }
  }
  return FuelEvInputs(
    mileage: mileage,
    mpg: mpg,
    gasPrice: gasPrice,
    miPerKwh: miPerKwh,
    elecPrice: elecPrice,
  );
}

/// 生成带结果数字的动态分享标题
///
/// 节省为正 → 省钱口径；为负 → 差额口径；空 → 兜底文案
String buildShareTitle(AnnualCostResult? result) {
  if (result == null) {
    return 'Fuel vs EV cost · see your annual savings in one minute';
  }
  if (result.savings > 0) {
    return 'An EV saves \$${formatAmount(result.savings)} a year vs a gas '
        'car — here is the math';
  }
  return '\$${formatAmount(result.savings.abs())} a year apart — run your own '
      'numbers';
}
