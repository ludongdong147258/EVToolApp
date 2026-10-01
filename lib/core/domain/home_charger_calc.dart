/// 私桩安装测算（纯函数）
///
/// 按线缆长度与充电桩功率估算安装成本：
/// 预估总额 = 基础安装包（含 INCLUDED_CABLE_M 米线缆）+ 超长线缆费。
/// 价格为占位假设，集中在常量中便于后续替换真实报价。
library;

import 'package:ev_tool_app/core/domain/numbers.dart';

export 'package:ev_tool_app/core/domain/numbers.dart' show formatAmount;

const int cableMin = 0; // 滑块下限（米）
const int cableMax = 100; // 滑块上限（米）
const int cableDefault = 30; // 默认线缆长度（米）
const int cableStep = 5; // 滑块步长（米）

const int includedCableM = 30; // 基础包含线缆长度（米）
const int extraCablePricePerM = 30; // 超长线缆单价 ¥/米

/// 充电桩功率选项
class PowerOption {
  const PowerOption({
    required this.id,
    required this.label,
    required this.voltage,
    required this.basePrice,
  });

  final String id;
  final String label;
  final String voltage;
  final int basePrice;
}

const List<PowerOption> powerOptions = [
  PowerOption(id: '3.5kw', label: '3.5kW', voltage: '220V', basePrice: 1950),
  PowerOption(id: '7kw', label: '7kW', voltage: '220V', basePrice: 2850),
  PowerOption(id: '11kw', label: '11kW', voltage: '380V', basePrice: 3600),
  PowerOption(id: '21kw', label: '21kW', voltage: '380V', basePrice: 4500),
];

/// 环境条件附加费（¥，设计稿口径：车库 +200、防护箱 +230；
/// 穿墙打孔设计稿未展示，假设 +150；地面车位不计费）
const Map<String, int> conditionSurcharges = {
  'undergroundGarage': 200,
  'wallDrilling': 150,
  'protectionBox': 230,
  'groundSpot': 0,
};

const String defaultPowerId = '7kw';

/// 已保存测算的最大条数（超出截断最旧的）
const int maxSavedEstimates = 20;

class HomeChargerInputs {
  const HomeChargerInputs({
    this.cableLength = cableDefault,
    this.powerId = defaultPowerId,
    this.conditions,
  });

  final dynamic cableLength; // 线缆长度（米，CABLE_MIN ~ CABLE_MAX）
  final String? powerId; // 充电桩功率选项 id（见 POWER_OPTIONS）
  final Map<String, bool>? conditions; // 环境条件布尔映射，缺省视为全部关闭

  HomeChargerInputs copyWith({
    dynamic cableLength,
    String? powerId,
    Map<String, bool>? conditions,
  }) {
    return HomeChargerInputs(
      cableLength: cableLength ?? this.cableLength,
      powerId: powerId ?? this.powerId,
      conditions: conditions ?? this.conditions,
    );
  }
}

const HomeChargerInputs defaultHomeChargerInputs = HomeChargerInputs();

/// 环境增项明细
class Surcharge {
  const Surcharge({required this.id, required this.price});

  final String id;
  final int price;
}

/// 私桩安装预估费用
class InstallEstimate {
  const InstallEstimate({
    required this.basePrice,
    required this.extraCableLength,
    required this.extraCableCost,
    required this.surcharges,
    required this.surchargeTotal,
    required this.total,
  });

  final int basePrice;
  final int extraCableLength;
  final int extraCableCost;
  final List<Surcharge> surcharges;
  final int surchargeTotal;
  final int total;
}

/// 计算私桩安装预估费用
///
/// 参数非法（长度非数字/越界、powerId 未知）时返回 null
InstallEstimate? calcInstallEstimate(HomeChargerInputs inputs) {
  final cableLength = toNumber(inputs.cableLength);
  final powerOption = powerOptions
      .where((option) => option.id == inputs.powerId)
      .firstOrNull;

  if (cableLength == null || powerOption == null) {
    return null;
  }
  if (cableLength < cableMin || cableLength > cableMax) {
    return null;
  }

  final extraLength = cableLength.round() - includedCableM;
  final extraCableLength = extraLength > 0 ? extraLength : 0;
  final extraCableCost = extraCableLength * extraCablePricePerM;
  final basePrice = powerOption.basePrice;

  /* 仅计入开启且单价 > 0 的环境增项 */
  final conditions = inputs.conditions ?? const <String, bool>{};
  final surcharges = <Surcharge>[];
  for (final entry in conditionSurcharges.entries) {
    if ((conditions[entry.key] ?? false) && entry.value > 0) {
      surcharges.add(Surcharge(id: entry.key, price: entry.value));
    }
  }
  var surchargeTotal = 0;
  for (final item in surcharges) {
    surchargeTotal += item.price;
  }

  return InstallEstimate(
    basePrice: basePrice,
    extraCableLength: extraCableLength,
    extraCableCost: extraCableCost,
    surcharges: surcharges,
    surchargeTotal: surchargeTotal,
    total: basePrice + extraCableCost + surchargeTotal,
  );
}

/// 从 storage 读出的单条测算（旧版直接保存的单对象无 id，
/// 由 estimateService 负责包一层，本模块只认列表元素形态）
class StoredEstimateInput {
  const StoredEstimateInput({
    required this.id,
    required this.cableLength,
    required this.powerId,
    this.spot,
    this.conditions,
    required this.savedAt,
  });

  final dynamic id;
  final dynamic cableLength;
  final String? powerId;
  final String? spot;
  final Map<String, bool>? conditions;
  final dynamic savedAt;

  StoredEstimateInput copyWith({
    dynamic id,
    dynamic cableLength,
    String? powerId,
    String? spot,
    Map<String, bool>? conditions,
    dynamic savedAt,
  }) {
    return StoredEstimateInput(
      id: id ?? this.id,
      cableLength: cableLength ?? this.cableLength,
      powerId: powerId ?? this.powerId,
      spot: spot ?? this.spot,
      conditions: conditions ?? this.conditions,
      savedAt: savedAt ?? this.savedAt,
    );
  }
}

/// 规范测算 { id, cableLength, powerId, spot, conditions, estimate, savedAt }
class StoredEstimate {
  const StoredEstimate({
    required this.id,
    required this.cableLength,
    required this.powerId,
    required this.spot,
    required this.conditions,
    required this.estimate,
    required this.savedAt,
  });

  final String id;
  final int cableLength;
  final String powerId;
  final String? spot;
  final Map<String, bool> conditions;
  final InstallEstimate estimate;
  final num savedAt;
}

/// 存储测算守卫：校验并按字段白名单拷贝（不透传未知字段）
///
/// 任一核心字段非法返回 null
StoredEstimate? normalizeStoredEstimate(StoredEstimateInput? raw) {
  if (raw == null || raw.id is! String || (raw.id as String).isEmpty) {
    return null;
  }
  final powerOption = powerOptions
      .where((option) => option.id == raw.powerId)
      .firstOrNull;
  if (powerOption == null) {
    return null;
  }
  final cableLength = toNumber(raw.cableLength);
  if (cableLength == null || cableLength < cableMin || cableLength > cableMax) {
    return null;
  }
  final savedAt = toNumber(raw.savedAt);
  if (savedAt == null || savedAt <= 0) {
    return null;
  }
  /* estimate 复核：用存的入参重算一遍，对不上（结构非法）即判脏数据 */
  final estimate = calcInstallEstimate(
    HomeChargerInputs(
      cableLength: cableLength,
      powerId: raw.powerId,
      conditions: raw.conditions,
    ),
  );
  if (estimate == null) {
    return null;
  }
  const spots = ['undergroundGarage', 'groundSpot'];
  final spot = spots.contains(raw.spot) ? raw.spot : null;
  return StoredEstimate(
    id: raw.id as String,
    cableLength: cableLength.round(),
    powerId: raw.powerId ?? '',
    spot: spot,
    conditions: Map<String, bool>.from(raw.conditions ?? const {}),
    estimate: estimate,
    savedAt: savedAt,
  );
}
