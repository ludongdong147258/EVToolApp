/// 年检维保备忘录（纯函数）
///
/// 按上牌日期推算年检周期（2022 新规：非营运小客车 10 年内仅第 6/10 年
/// 上线检测，第 2/4/8 年纯线上申领检验标志，10 年后每年上线一次），
/// 按当前里程推算新能源通用维保节点（km / 时间双周期，先到为准）。
/// 节点为通用周期估算，仅供参考，不构成维修建议。
library;

import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';

const int mileageMin = 1; // 当前里程下限（km，必填，不允许 0/空）
const int mileageMax = 2000000; // 当前里程合理上限（km）

const int dueSoonDays = 30; // 年检「即将到期」阈值（天）
const int insuranceSoonDays = dueSoonDays; // 保险「即将到期」阈值（天）
const int maintSoonKm = 1000; // 维保「临近」里程阈值（km）
const int maintSoonDays = 30; // 维保「临近」日期阈值（天）
const int tireReplaceMonths = 60; // 轮胎建议更换周期（月，即 5 年）
const int tireSoonDays = 180; // 轮胎更换提前提示窗口（天，约半年）

/// 年检节点类型
class InspectionPlanNode {
  const InspectionPlanNode({required this.years, required this.type});

  final int years;
  final String type; // "badge" 申领检验标志 / "online" 上线检测
}

/// 10 年内年检节点表（2022 新规：非营运小微型客车）
const List<InspectionPlanNode> inspectionPlan = [
  InspectionPlanNode(years: 2, type: 'badge'),
  InspectionPlanNode(years: 4, type: 'badge'),
  InspectionPlanNode(years: 6, type: 'online'),
  InspectionPlanNode(years: 8, type: 'badge'),
  InspectionPlanNode(years: 10, type: 'online'),
];

/// 10 年后每年上线检测，里程碑生成到第 30 年封顶（再往后无展示意义）
const int maxAnnualYears = 30;

/// 新能源通用维保节点（km / 月双周期，先到为准；起始自上牌时点估算）
class MaintenanceNodeDef {
  const MaintenanceNodeDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.intervalKm,
    required this.intervalMonths,
    this.soonDays,
  });

  final String id;
  final String label;
  final String icon;
  final int? intervalKm; // null 表示纯时间周期，不按里程
  final int intervalMonths;
  final int? soonDays; // 覆盖默认 30 天提示窗口
}

const List<MaintenanceNodeDef> maintenanceNodes = [
  MaintenanceNodeDef(
    id: 'powertrain',
    label: 'Battery/motor/electronics check',
    icon: 'build',
    intervalKm: 10000,
    intervalMonths: 12,
  ),
  MaintenanceNodeDef(
    id: 'coolant',
    label: 'Coolant check & replacement',
    icon: 'speed',
    intervalKm: 40000,
    intervalMonths: 24,
  ),
  MaintenanceNodeDef(
    id: 'brakeFluid',
    label: 'Brake fluid check & replacement',
    icon: 'warning',
    intervalKm: 40000,
    intervalMonths: 24,
  ),
  MaintenanceNodeDef(
    id: 'tireRotation',
    label: 'Tire rotation check',
    icon: 'directions_car',
    intervalKm: 10000,
    intervalMonths: 12,
  ),
  MaintenanceNodeDef(
    id: 'tireReplace',
    label: 'Tire replacement (by age)',
    icon: 'task_alt',
    intervalKm: null,
    intervalMonths: tireReplaceMonths,
    soonDays: tireSoonDays,
  ),
];

/// 静态科普（页面内直接渲染，无交互状态）
class ScienceSection {
  const ScienceSection({
    required this.id,
    required this.icon,
    required this.title,
    required this.lines,
  });

  final String id;
  final String icon;
  final String title;
  final List<String> lines;
}

const List<ScienceSection> scienceSections = [
  ScienceSection(
    id: 'exempt',
    icon: 'verified_user',
    title: 'What is the 6-year inspection exemption',
    lines: [
      'Non-commercial passenger cars (9 seats or fewer) only need in-person inspections in years 6 and 10 within the first 10 years.',
      'Years 2, 4 and 8 require no in-person inspection — simply claim the inspection sticker online (via the 12123 traffic app).',
      'Exemption does not mean no application: the inspection sticker must still be claimed online on schedule.',
    ],
  ),
  ScienceSection(
    id: 'online',
    icon: 'directions_car',
    title: 'What the in-person inspection covers',
    lines: [
      'The year-6 and year-10 in-person inspections cover exterior, lighting, braking and other items.',
      'Battery electric vehicles have no emissions test; the focus is on brakes, lights and chassis.',
      'After 10 years, an in-person inspection is required every year.',
    ],
  ),
  ScienceSection(
    id: 'nev',
    icon: 'menu_book',
    title: 'EV maintenance essentials',
    lines: [
      'Have the battery/motor/electronics system checked once a year or every 10,000 km.',
      'Replace coolant roughly every 2 years or 40,000 km (battery cooling system).',
      'Check and replace brake fluid roughly every 2 years or 40,000 km; rotate and inspect tires every 10,000 km.',
      'Replace tires after 5-6 years of use or when worn to the limit, whichever comes first.',
    ],
  ),
];

const String memoDisclaimer =
    '* The milestones above are generic interval estimates for reference only '
    'and do not constitute maintenance advice; inspection policies vary by '
    'region, so refer to your local vehicle administration office.';

const int _msPerDay = 24 * 60 * 60 * 1000;

const Map<String, String> _typeLabels = {
  'badge': 'Inspection sticker application',
  'online': 'In-person inspection',
};

/// 完整年检节点表：10 年内计划表 + 第 11~30 年每年上线
List<InspectionPlanNode> _buildFullPlan() {
  final annual = <InspectionPlanNode>[
    for (var years = 11; years <= maxAnnualYears; years += 1)
      InspectionPlanNode(years: years, type: 'online'),
  ];
  return [...inspectionPlan, ...annual];
}

final List<InspectionPlanNode> _fullPlan = _buildFullPlan();

final RegExp _dateRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// 解析 "YYYY-MM-DD" 为本地时区日期（零点）
///
/// 格式非法或日期不存在（如 2025-02-30）时返回 null
DateTime? parseDateStr(dynamic value) {
  if (value is! String) {
    return null;
  }
  final match = _dateRe.firstMatch(value);
  if (match == null) {
    return null;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  final isValid = date.year == year && date.month == month && date.day == day;
  return isValid ? date : null;
}

/// Date → "YYYY-MM-DD"（本地时区，补零）
String _formatDate(DateTime date) {
  return '${date.year}-${pad2(date.month)}-${pad2(date.day)}';
}

/// 按月加法（唯一日历原语）：日超出目标月天数时收敛到月末
/// （如 2024-01-31 + 1 月 → 2024-02-29）；纯函数，不改入参
String? addMonths(String dateStr, num months) {
  final base = parseDateStr(dateStr);
  if (base == null || !months.isFinite) {
    return null;
  }
  final targetMonthIndex = (base.month - 1) + months.truncate();
  /* DateTime(年, 月+1, 0) 即目标月最后一天（月索引越界会自动进位） */
  final lastDay = DateTime(base.year, targetMonthIndex + 2, 0).day;
  final day = base.day < lastDay ? base.day : lastDay;
  return _formatDate(DateTime(base.year, targetMonthIndex + 1, day));
}

/// 按年加法（addMonths 的年语义包装）
String? addYears(String dateStr, num years) {
  if (!years.isFinite) {
    return null;
  }
  return addMonths(dateStr, years * 12);
}

/// 目标日期距今天的天数（未来为正，按整天计，不含时分秒）
///
/// 入参非法返回 null；now 可注入（默认当前时间）
int? diffDays(String dateStr, [DateTime? now]) {
  final target = parseDateStr(dateStr);
  if (target == null) {
    return null;
  }
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  return ((target.millisecondsSinceEpoch - today.millisecondsSinceEpoch) /
          _msPerDay)
      .round();
}

/// 中文短日期：同年显示 "Sep 15"，跨年显示 "Aug 25, 2027"（省空间）
///
/// 入参非法时原样返回（兜底展示）
String formatCnDate(dynamic dateStr, [DateTime? now]) {
  final date = parseDateStr(dateStr);
  if (date == null) {
    return dateStr.toString();
  }
  final current = now ?? DateTime.now();
  final sameYear = date.year == current.year;
  final core = '${monthShortNames[date.month - 1]} ${date.day}';
  return sameYear ? core : '$core, ${date.year}';
}

/// 两个日期字符串之间的整天数（from → to，to 在后为正）；任一非法返回 null
int? _daysBetween(String fromStr, String toStr) {
  final from = parseDateStr(fromStr);
  final to = parseDateStr(toStr);
  if (from == null || to == null) {
    return null;
  }
  return ((to.millisecondsSinceEpoch - from.millisecondsSinceEpoch) / _msPerDay)
      .round();
}

/// 状态常量（年检/维保/保险共用口径）
const String statusOverdue = 'overdue';
const String statusSoon = 'soon';
const String statusNormal = 'normal';

/// 年检节点状态：已过期 / 即将到期（≤30 天）/ 正常
String _inspectionStatus(int daysRemaining) {
  if (daysRemaining < 0) {
    return statusOverdue;
  }
  if (daysRemaining <= dueSoonDays) {
    return statusSoon;
  }
  return statusNormal;
}

/// 年检时间表里程碑
class InspectionMilestone {
  const InspectionMilestone({
    required this.key,
    required this.years,
    required this.type,
    required this.typeLabel,
    required this.dueDate,
    required this.daysRemaining,
    required this.status,
    required this.cycleStartDate,
    required this.progress,
  });

  final String key;
  final int years;
  final String type;
  final String typeLabel;
  final String dueDate;
  final int daysRemaining;
  final String status;
  final String cycleStartDate;
  final double progress;
}

/// 年检时间表
class InspectionSchedule {
  const InspectionSchedule({
    required this.milestones,
    required this.next,
    required this.latestPast,
  });

  final List<InspectionMilestone> milestones;
  final InspectionMilestone? next;
  final InspectionMilestone? latestPast;
}

/// 计算年检时间表
///
/// registrationDate 非法时返回 null。不追踪办理状态，过期节点由页面弱化展示
InspectionSchedule? calcInspectionSchedule(
  String registrationDate, [
  DateTime? now,
]) {
  if (parseDateStr(registrationDate) == null) {
    return null;
  }
  final milestones = <InspectionMilestone>[];
  /* 周期起点：首个节点为上牌日，其后为上一节点的到期日（供进度条计算） */
  var cycleStart = registrationDate;
  for (final plan in _fullPlan) {
    final dueDate = addYears(registrationDate, plan.years);
    if (dueDate == null) {
      continue;
    }
    final daysRemaining = diffDays(dueDate, now);
    if (daysRemaining == null) {
      continue;
    }
    final cycleTotal = _daysBetween(cycleStart, dueDate) ?? 0;
    double progress;
    if (cycleTotal > 0) {
      final ratio = (cycleTotal - daysRemaining) / cycleTotal;
      progress = ratio < 0 ? 0 : (ratio > 1 ? 1 : ratio);
    } else {
      progress = 1;
    }
    milestones.add(
      InspectionMilestone(
        key: 'y${plan.years}',
        years: plan.years,
        type: plan.type,
        typeLabel: _typeLabels[plan.type] ?? plan.type,
        dueDate: dueDate,
        daysRemaining: daysRemaining,
        status: _inspectionStatus(daysRemaining),
        cycleStartDate: cycleStart,
        progress: progress,
      ),
    );
    cycleStart = dueDate;
  }
  InspectionMilestone? next;
  for (final item in milestones) {
    if (item.daysRemaining >= 0) {
      next = item;
      break;
    }
  }
  InspectionMilestone? latestPast;
  for (final item in milestones.reversed) {
    if (item.daysRemaining < 0) {
      latestPast = item;
      break;
    }
  }
  return InspectionSchedule(
    milestones: milestones,
    next: next,
    latestPast: latestPast,
  );
}

/// 里程格式化：10000 → "10,000"（千分位）
String _formatKm(int km) {
  return formatAmount(km);
}

/// 周期年数文本：12 → "1"、24 → "2"、18 → "1.5"
String _yearsText(int months) {
  return months % 12 == 0
      ? (months ~/ 12).toString()
      : (months / 12).toString();
}

/// 日期周期自上牌日起按 intervalMonths 递进的下一个未过期节点
String _nextDateCycle(
  String registrationDate,
  int intervalMonths,
  DateTime now,
) {
  var months = intervalMonths;
  final first = addMonths(registrationDate, months);
  if (first == null) {
    return registrationDate;
  }
  var dueDate = first;
  while (true) {
    final days = diffDays(dueDate, now);
    if (days == null || days >= 0) {
      break;
    }
    months += intervalMonths;
    final next = addMonths(registrationDate, months);
    if (next == null) {
      break;
    }
    dueDate = next;
  }
  return dueDate;
}

/// 维保节点提示文案（周期说明 + 下次触发条件）
String _buildHint(
  MaintenanceNodeDef node,
  int? kmRemaining,
  String nextDueDate,
) {
  final intervalKm = node.intervalKm;
  final intervalText = intervalKm != null
      ? 'Every ${_formatKm(intervalKm)} km / ${_yearsText(node.intervalMonths)} yr'
      : 'Replace within ${_yearsText(node.intervalMonths)} yr';
  final triggerText = intervalKm != null && kmRemaining != null
      ? 'in ${_formatKm(kmRemaining)} km or by ${formatMonthDay(nextDueDate)}'
      : 'by ${formatMonthDay(nextDueDate)}';
  return '$intervalText · $triggerText';
}

/// 维保节点计算结果
class MaintenanceNodeStatus {
  const MaintenanceNodeStatus({
    required this.id,
    required this.label,
    required this.icon,
    required this.nextDueKm,
    required this.kmRemaining,
    required this.nextDueDate,
    required this.daysRemaining,
    required this.status,
    required this.hint,
  });

  final String id;
  final String label;
  final String icon;
  final int? nextDueKm;
  final int? kmRemaining;
  final String nextDueDate;
  final int daysRemaining;
  final String status;
  final String hint;
}

/// 计算新能源通用维保节点（km / 时间双周期，先到为准）
///
/// 任一入参非法（日期坏 / 里程非数字或越界）返回 null
List<MaintenanceNodeStatus>? calcMaintenanceNodes(
  String registrationDate,
  dynamic mileageKm, [
  DateTime? now,
]) {
  if (parseDateStr(registrationDate) == null) {
    return null;
  }
  final mileage = toNumber(mileageKm);
  if (mileage == null || mileage < mileageMin || mileage > mileageMax) {
    return null;
  }
  final roundedMileage = mileage.round();
  final currentTime = now ?? DateTime.now();

  return [
    for (final node in maintenanceNodes)
      _calcNodeStatus(node, registrationDate, roundedMileage, currentTime),
  ];
}

/// 单个维保节点的状态推算
MaintenanceNodeStatus _calcNodeStatus(
  MaintenanceNodeDef node,
  String registrationDate,
  int roundedMileage,
  DateTime now,
) {
  final intervalKm = node.intervalKm;
  final nextDueKm = intervalKm != null
      ? ((roundedMileage + intervalKm - 1) ~/ intervalKm) * intervalKm
      : null;
  final kmRemaining = nextDueKm != null ? nextDueKm - roundedMileage : null;
  final nextDueDate = _nextDateCycle(
    registrationDate,
    node.intervalMonths,
    now,
  );
  final daysRemaining = diffDays(nextDueDate, now) ?? 0;

  var status = statusNormal;
  /* 到里程或到日均视为「已到期」（与 kmRemaining <= 0 口径一致） */
  if ((kmRemaining != null && kmRemaining <= 0) || daysRemaining <= 0) {
    status = statusOverdue;
  } else if ((kmRemaining != null && kmRemaining <= maintSoonKm) ||
      daysRemaining <= (node.soonDays ?? maintSoonDays)) {
    status = statusSoon;
  }

  return MaintenanceNodeStatus(
    id: node.id,
    label: node.label,
    icon: node.icon,
    nextDueKm: nextDueKm,
    kmRemaining: kmRemaining,
    nextDueDate: nextDueDate,
    daysRemaining: daysRemaining,
    status: status,
    hint: _buildHint(node, kmRemaining, nextDueDate),
  );
}

/// 保险到期状态（独立于上牌日期/里程，仅填保险日期即可计算）
class InsuranceStatus {
  const InsuranceStatus({
    required this.status,
    required this.daysRemaining,
    required this.expiryDate,
  });

  final String status;
  final int daysRemaining;
  final String expiryDate;
}

/// 保险到期状态
///
/// status 口径与年检一致：已过期 / 即将到期（≤ INSURANCE_SOON_DAYS 天，
/// 当天到期算 soon）/ 正常；日期未记录/非法返回 null
InsuranceStatus? calcInsuranceStatus(String? expiryDate, [DateTime? now]) {
  if (expiryDate == null || parseDateStr(expiryDate) == null) {
    return null;
  }
  final daysRemaining = diffDays(expiryDate, now);
  if (daysRemaining == null) {
    return null;
  }
  final status = daysRemaining < 0
      ? statusOverdue
      : daysRemaining <= insuranceSoonDays
      ? statusSoon
      : statusNormal;
  return InsuranceStatus(
    status: status,
    daysRemaining: daysRemaining,
    expiryDate: expiryDate,
  );
}

/// 从 storage 读出的单条备忘（宽容形态，经 normalizeStoredMemo 校验归一）
class MemoInput {
  const MemoInput({
    required this.id,
    required this.vehicleId,
    this.vehicleName,
    required this.registrationDate,
    required this.mileageKm,
    this.insuranceExpiryDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final dynamic id;
  final dynamic vehicleId;
  final String? vehicleName;
  final String registrationDate;
  final dynamic mileageKm;
  final String? insuranceExpiryDate;
  final dynamic createdAt;
  final dynamic updatedAt;

  MemoInput copyWith({
    dynamic id,
    dynamic vehicleId,
    String? vehicleName,
    String? registrationDate,
    dynamic mileageKm,
    String? insuranceExpiryDate,
    dynamic createdAt,
    dynamic updatedAt,
  }) {
    return MemoInput(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleName: vehicleName ?? this.vehicleName,
      registrationDate: registrationDate ?? this.registrationDate,
      mileageKm: mileageKm ?? this.mileageKm,
      insuranceExpiryDate: insuranceExpiryDate ?? this.insuranceExpiryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 规范备忘（memoService.getMemos() 产物形态）
class MemoItem {
  const MemoItem({
    required this.id,
    required this.vehicleId,
    required this.vehicleName,
    required this.registrationDate,
    required this.mileageKm,
    required this.insuranceExpiryDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String vehicleId;
  final String vehicleName;
  final String registrationDate;
  final int mileageKm;
  final String? insuranceExpiryDate;
  final num createdAt;
  final num updatedAt;

  /// 序列化（与备忘仓储的存储结构一致，供备份导出 jsonEncode 使用）。
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'vehicleId': vehicleId,
    'vehicleName': vehicleName,
    'registrationDate': registrationDate,
    'mileageKm': mileageKm,
    'insuranceExpiryDate': insuranceExpiryDate,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

/// 存储备忘守卫：校验并按字段白名单拷贝（不透传未知字段）
///
/// 任一核心字段非法返回 null（insuranceExpiryDate 为选填：未记录/非法 → null）
MemoItem? normalizeStoredMemo(MemoInput? raw) {
  if (raw == null ||
      raw.id is! String ||
      (raw.id as String).isEmpty ||
      raw.vehicleId is! String ||
      (raw.vehicleId as String).isEmpty) {
    return null;
  }
  if (parseDateStr(raw.registrationDate) == null) {
    return null;
  }
  final mileageKm = toNumber(raw.mileageKm);
  if (mileageKm == null || mileageKm < mileageMin || mileageKm > mileageMax) {
    return null;
  }
  final createdAt = toNumber(raw.createdAt);
  final updatedAt = toNumber(raw.updatedAt);
  if (createdAt == null || createdAt <= 0) {
    return null;
  }
  if (updatedAt == null || updatedAt <= 0) {
    return null;
  }
  return MemoItem(
    id: raw.id as String,
    vehicleId: raw.vehicleId as String,
    vehicleName: raw.vehicleName ?? '',
    registrationDate: raw.registrationDate,
    mileageKm: mileageKm.round(),
    /* 存量备忘无保险字段/脏数据 → null（选填，读取宽容） */
    insuranceExpiryDate:
        raw.insuranceExpiryDate != null &&
            parseDateStr(raw.insuranceExpiryDate) != null
        ? raw.insuranceExpiryDate
        : null,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
