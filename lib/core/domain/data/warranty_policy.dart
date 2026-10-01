/// 三电质保政策手册（纯静态对照表）
///
/// 移植自 EVTool 小程序 src/lib/warrantyPolicy.js。
/// 整理自各车企官网、随车《保修手册》及公开公告（整理日期见 [warrantyDataDate]）。
/// 各车企政策随车型、购车时间与官方活动动态调整，内容仅供参考，
/// 具体以购车合同及车企最新政策为准。
library;

/// 数据整理日期（YYYY-MM），免责声明与页面角标统一读取此常量
const String warrantyDataDate = '2026-09';

/// 质保对照字段定义（页面渲染顺序即数组顺序）
class WarrantyField {
  const WarrantyField({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final String icon;
}

/// 国家规定基线条目
class WarrantyBaselineRule {
  const WarrantyBaselineRule({
    required this.icon,
    required this.label,
    required this.text,
  });

  final String icon;
  final String label;
  final String text;
}

/// 国家规定基线（法定底线 + 2026 年两项新国标，页面 Hero 下方独立卡片）
class WarrantyBaseline {
  const WarrantyBaseline({
    required this.title,
    required this.note,
    required this.rules,
  });

  final String title;
  final String note;
  final List<WarrantyBaselineRule> rules;
}

/// 品牌摘要（列表卡片两行短文案）
class WarrantySummary {
  const WarrantySummary({required this.vehicle, required this.powertrain});

  final String vehicle;
  final String powertrain;
}

/// 单个车企的三电质保政策
class WarrantyBrand {
  const WarrantyBrand({
    required this.id,
    required this.name,
    required this.tagline,
    required this.offersLifetimeWarranty,
    required this.hasDegradationStandard,
    required this.voidsLifetimeOnTransfer,
    required this.summary,
    required this.fields,
  });

  final String id;
  final String name;
  final String tagline;
  final bool offersLifetimeWarranty;
  final bool hasDegradationStandard;
  final bool voidsLifetimeOnTransfer;
  final WarrantySummary summary;

  /// 六个固定展示字段，key 见 [warrantyFields] 的 id
  final Map<String, String> fields;
}

/// 六个固定展示字段（页面渲染顺序即数组顺序）
const List<WarrantyField> warrantyFields = [
  WarrantyField(id: 'vehicle', label: '整车质保', icon: 'directions_car'),
  WarrantyField(id: 'powertrain', label: '三电质保', icon: 'battery_charging_full'),
  WarrantyField(id: 'lifetime', label: '终身质保条件', icon: 'verified_user'),
  WarrantyField(id: 'degradation', label: '电池衰减保修', icon: 'science'),
  WarrantyField(id: 'transfer', label: '过户后权益', icon: 'compare_arrows'),
  WarrantyField(id: 'exclusion', label: '免责情形', icon: 'warning'),
];

/// 国家规定基线（法定底线 + 2026 年两项新国标，页面 Hero 下方独立卡片）
const WarrantyBaseline warrantyBaseline = WarrantyBaseline(
  title: '国家规定基线',
  note: '各车企承诺不得低于法定底线；两项新国标自 2026 年 7 月 1 日起实施。',
  rules: [
    WarrantyBaselineRule(
      icon: 'task_alt',
      label: '法定质保底线',
      text: '乘用车三电系统（电池、电机、电控）质保不低于 8 年或 12 万公里（GB/T 31484 及国家相关要求）',
    ),
    WarrantyBaselineRule(
      icon: 'battery_charging_full',
      label: '电池耐久性新国标',
      text:
          'GB/T 46991.1-2025（2026-07-01 实施）：5 年或 10 万公里电池容量不低于 82%、8 年或 16 万公里不低于 75%，并要求向消费者展示电池健康度',
    ),
    WarrantyBaselineRule(
      icon: 'whatshot',
      label: '电池安全新国标',
      text: 'GB 38031-2025（2026-07-01 实施）：热失控后「不起火、不爆炸」为强制指标，取代旧「5 分钟逃生」要求',
    ),
  ],
);

/// 主流车企三电质保政策对照（渲染顺序即数组顺序）
const List<WarrantyBrand> warrantyBrands = [
  WarrantyBrand(
    id: 'byd',
    name: '比亚迪',
    tagline: '首任车主三电终身质保（有限制条件）',
    offersLifetimeWarranty: true,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(vehicle: '整车 6年/15万', powertrain: '三电 终身·限首任'),
    fields: {
      'vehicle': '整车 6 年或 15 万公里（以先到为准）',
      'powertrain': '首任车主非营运车辆动力电池、电芯终身质保；电机、电控等其余三电部件 8 年或 15 万公里',
      'lifetime':
          '限首任车主 + 非营运用途 + 按保修手册要求在授权服务店定期保养 + 事故维修在官方授权店进行；早期车型另有连续 12 个月不超过 3 万公里限制，2025 年 9 月起部分新车型已放宽或取消年里程上限（以购车时条款为准）',
      'degradation': '官方未公布统一衰减百分比门槛，动力电池是否达到质保条件以官方检测认定为准',
      'transfer': '过户后终身质保失效，动力电池恢复为 8 年或 15 万公里随车质保',
      'exclusion': '未按期保养、私自改装三电或电路、事故/泡水损伤电池、长期亏电存放、营运用途',
    },
  ),
  WarrantyBrand(
    id: 'xpeng',
    name: '小鹏',
    tagline: '基础三电 8 年/16 万公里，限时权益可升级终身',
    offersLifetimeWarranty: true,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(vehicle: '整车 5年/12万', powertrain: '三电 8年/16万'),
    fields: {
      'vehicle': '整车 5 年或 12 万公里（以先到为准）',
      'powertrain':
          '三电系统基础质保 8 年或 16 万公里；部分车型限时下订权益可升级首任车主三电终身质保（如 2026 款 X9 纯电版，以官方活动规则为准）',
      'lifetime': '升级终身质保限首任车主 + 非营运用途 + 全程官方渠道保养维修 + 年行驶里程限制（以购车时活动规则为准）',
      'degradation': '官方未公布统一衰减百分比门槛，动力电池质保以官方授权检测标准认定',
      'transfer': '过户后终身质保权益终止，按 8 年或 16 万公里基础三电质保随车执行',
      'exclusion': '改装三电系统、未按期官方保养、营运用途、参与赛事竞技、事故后非授权维修',
    },
  ),
  WarrantyBrand(
    id: 'xiaomi',
    name: '小米汽车',
    tagline: '无终身质保，三电 8 年/16 万公里',
    offersLifetimeWarranty: false,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: false,
    summary: WarrantySummary(vehicle: '整车 5年/10万', powertrain: '三电 8年/16万'),
    fields: {
      'vehicle': '整车 5 年或 10 万公里（以先到为准）',
      'powertrain': '动力电池与驱动系统 8 年或 16 万公里（SU7/YU7 系列）',
      'lifetime': '未推出三电终身质保政策，首任车主亦按固定年限/里程执行',
      'degradation':
          '官方未公布统一衰减门槛；据《用户手册》及公开资料，质保期内电池容量衰减超 30%（保持率低于 70%）可申请官方检测，以官方认定为准',
      'transfer': '质保随车不随人，过户后剩余年限/里程质保继续有效',
      'exclusion': '私自改装或拆解三电、未按保养规范保养、营运用途、越野/赛道等滥用场景、事故损伤',
    },
  ),
  WarrantyBrand(
    id: 'zeekr',
    name: '极氪',
    tagline: '首任三电终身质保（2026 新政年里程 ≤6 万），基础 8 年/20 万',
    offersLifetimeWarranty: true,
    hasDegradationStandard: true,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(vehicle: '整车 6年/15万', powertrain: '三电 终身·限首任'),
    fields: {
      'vehicle': '整车 6 年或 15 万公里（以各车型保修手册为准）',
      'powertrain': '首任车主非营运车辆三电（动力电池、驱动电机、电机控制器）终身质保；基础三电质保 8 年或 20 万公里',
      'lifetime':
          '2025 年 12 月公布新政（过渡期至 2026 年 3 月 31 日）：限首任车主 + 非营运用途 + 每年行驶不超过 6 万公里（超出可申请豁免）+ 按保修手册在官方渠道保养维修；过渡期后新订单统一执行新规',
      'degradation':
          '官方公布电池容量衰减限值：2 年或 5 万公里内不低于 92%、4 年或 10 万公里内不低于 84%、8 年或 20 万公里内达标（以官方细则为准）',
      'transfer': '过户后终身质保终止，按 8 年或 20 万公里基础三电质保随车执行',
      'exclusion': '改装三电、未按期官方保养、营运用途、事故后非授权维修、泡水及外部火源损伤',
    },
  ),
  WarrantyBrand(
    id: 'nio',
    name: '蔚来',
    tagline: '首任车主三电 10 年不限里程，BaaS 电池由蔚来维护',
    offersLifetimeWarranty: true,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(vehicle: '整车 6年/15万', powertrain: '三电 10年·限首任'),
    fields: {
      'vehicle': '整车 6 年或 15 万公里（以《三包凭证》及订单权益为准）',
      'powertrain': '首任车主三电系统 10 年不限里程质保；选择电池租用（BaaS）的用户车端电池由蔚来持有并承担维护责任',
      'lifetime':
          '限首任车主 + 非营运用途 + 不得过户（过户即失效）+ 按官方保养规范保养；2025 年起官方加强用途审查，营运用途将取消首任专享权益',
      'degradation': 'BaaS 用户电池衰减由蔚来负责；自有电池官方未公布统一百分比门槛，以官方检测为准',
      'transfer': '过户后首任专享质保终止，后续车主按法定基础质保随车执行（以官方政策为准）',
      'exclusion': '营运用途、改装三电、未按保养规范、事故后非授权维修、电池外接放电等滥用行为',
    },
  ),
  WarrantyBrand(
    id: 'tesla',
    name: '特斯拉',
    tagline: '三电 8 年/16-24 万公里，容量保持 70% 阈值',
    offersLifetimeWarranty: false,
    hasDegradationStandard: true,
    voidsLifetimeOnTransfer: false,
    summary: WarrantySummary(vehicle: '整车 4年/8万', powertrain: '三电 8年/16-24万'),
    fields: {
      'vehicle': '基础整车质保 4 年或 8 万公里（以先到为准）',
      'powertrain':
          '电池与驱动单元 8 年或 16 万公里（标准续航版）；8 年或 24 万公里（长续航及 Performance 版，视车型而定）',
      'lifetime': '无终身质保政策，全部按固定年限/里程执行',
      'degradation': '三电质保期内电池容量保持率低于 70% 可申请质保（官方载明 70% 阈值）',
      'transfer': '质保随车（绑定 VIN），过户后剩余质保继续有效',
      'exclusion': '电池正常衰减（未低于 70% 阈值）、私自拆解改装电池、碰撞/泡水损伤、赛道等滥用场景',
    },
  ),
  WarrantyBrand(
    id: 'geely',
    name: '吉利',
    tagline: '银河系列首任车主可享三电终身质保',
    offersLifetimeWarranty: true,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(vehicle: '整车 6年/15万', powertrain: '三电 终身·限首任'),
    fields: {
      'vehicle': '银河/几何等新能源系列多为整车 6 年或 15 万公里（以各车型保修手册为准）',
      'powertrain':
          '银河等新能源系列首任非营运车主三电终身质保；不满足终身条件的车型基础三电质保 8 年或 12 万公里（以各车型保修手册为准）',
      'lifetime': '限首任车主 + 非营运用途 + 按保修手册官方保养 + 年行驶里程限制（以保修手册为准）',
      'degradation': '官方未公布统一衰减百分比门槛，动力电池以官方授权检测认定为准',
      'transfer': '过户后终身质保权益失效，按基础三电质保随车执行',
      'exclusion': '改装三电、未按期官方保养、营运用途、事故后非授权维修、电池进水/外壳破损',
    },
  ),
  WarrantyBrand(
    id: 'aito',
    name: '问界',
    tagline: '首任非营运三电终身质保，基础 8 年/16 万',
    offersLifetimeWarranty: true,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(vehicle: '整车 4年/10万', powertrain: '三电 终身·限首任'),
    fields: {
      'vehicle': '整车 4 年或 10 万公里（以各车型保修手册为准）',
      'powertrain': '三电系统与增程器 8 年或 16 万公里；首任非营运车主可享三电终身质保（以购车时权益为准）',
      'lifetime':
          '限首任车主 + 非营运用途 + 按保修手册在官方渠道保养维修；官方承诺动力电池故障、异常衰减、起火自燃免费换新（以官方条款为准）',
      'degradation': '官方承诺电池异常衰减免费换新，未公布统一百分比门槛，以官方检测认定为准',
      'transfer': '过户后终身质保终止，按 8 年或 16 万公里基础三电质保随车执行',
      'exclusion': '改装三电、未按期官方保养、营运用途、事故后非授权维修、外部火源/泡水损伤',
    },
  ),
  WarrantyBrand(
    id: 'lixiang',
    name: '理想',
    tagline: '2022 年 2 月起取消终身质保，基础三电 8 年/16 万',
    offersLifetimeWarranty: true,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(vehicle: '整车 5年/10万', powertrain: '三电 8年/16万'),
    fields: {
      'vehicle': '整车 5 年或 10 万公里（以先到为准）',
      'powertrain':
          '三电系统（增程车型含增程器）8 年或 16 万公里（L 系列/i8 等现行车型；理想 ONE 为 8 年或 12 万公里）；2022 年 2 月 1 日前购车的首任车主仍享三电及增程系统终身质保',
      'lifetime':
          '新购车无标配终身质保；2024 年 7 月起可付费购买整车+三电终身质保（不限年限/里程）；理想 ONE 车主换购新车可获对应终身质保权益（「接力计划」，窗口期至 2026 年 12 月 31 日）',
      'degradation': '官方未公布统一衰减百分比门槛，以《保修手册》约定及官方检测为准',
      'transfer': '终身质保不随车转移，过户后按剩余基础三电质保随车执行',
      'exclusion': '改装三电、未按期官方保养、营运用途、事故后非授权维修、越野/赛道等滥用场景',
    },
  ),
  WarrantyBrand(
    id: 'leapmotor',
    name: '零跑',
    tagline: '首任非营运「四项终身免费质保」（含整车）',
    offersLifetimeWarranty: true,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(vehicle: '整车 终身·限首任', powertrain: '三电 终身·限首任'),
    fields: {
      'vehicle': '首任非营运车主整车终身免费质保（以购车时权益为准）',
      'powertrain': '首任非营运车主电池、电驱、电控三电终身免费质保',
      'lifetime':
          '限首任车主 + 非营运用途 + 按保修手册在官方渠道保养维修（以购车时权益条款为准）；2025 年 4 月起部分官方渠道购车的老款首任车主也被追加授予三电终身质保',
      'degradation': '官方未公布统一衰减百分比门槛，以《保修手册》约定及官方检测为准',
      'transfer': '过户后终身质保失效，按基础质保随车执行（以保修手册为准）',
      'exclusion': '营运用途、改装三电、未按期官方保养、事故后非授权维修',
    },
  ),
  WarrantyBrand(
    id: 'aion',
    name: '埃安',
    tagline: '首任非营运三电终身质保（部分车型限年里程 3 万）',
    offersLifetimeWarranty: true,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(vehicle: '整车 4年/15万', powertrain: '三电 终身·限首任'),
    fields: {
      'vehicle': '多数车型整车 4 年或 15 万公里；部分新车型首任车主含整车终身质保（以购车合同为准）',
      'powertrain': '首任非营运车主三电终身质保；基础三电质保 8 年或 15 万公里（以各车型保修手册为准）',
      'lifetime':
          '限首任私人车主 + 非营运用途 + 按保修手册在官方渠道使用原厂件维修保养 + 每自然年行驶不超过 3 万公里，超出降为基础质保（以购车时条款为准）',
      'degradation':
          '官方未公布统一衰减门槛；搭载中创新航 177Ah 电池的 AION S/V/Y 车辆享专项质保升级：私人营运车电池质保由 8 年或 15 万公里延长至 8 年或 30 万公里，可免费检测并按结果维修/更换（以官方公告为准）',
      'transfer': '过户后终身质保失效，按基础三电质保随车执行',
      'exclusion': '营运用途、改装三电、未按期官方保养、事故后非授权维修、年里程超限（部分车型）',
    },
  ),
];

/// 页面底部免责声明
const String warrantyDisclaimer =
    '以上内容整理自各车企公开官方文档及国家/行业标准（截至 $warrantyDataDate），'
    '仅供参考，具体以购车合同及车企最新政策为准。';

/// 按品牌 id 取品牌（页面锚点跳转与单测用），未命中返回 null
WarrantyBrand? getBrandById(String id) {
  for (final brand in warrantyBrands) {
    if (brand.id == id) {
      return brand;
    }
  }
  return null;
}
