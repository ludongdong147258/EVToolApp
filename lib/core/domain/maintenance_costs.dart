/// 养车支出记录（纯函数）
///
/// 移植自 EVTool 小程序 src/lib/maintenanceCosts.js。
/// 覆盖养车支出（保险/停车/洗车/保养等）台账所需的全部无副作用逻辑：
/// 类型枚举、表单 → 规范记录、存储脏数据守卫、排序筛选、
/// 时间范围预设（本月/近三月/本年/全部）、汇总聚合，
/// 以及充电 + 养车合并报表计算。
/// 约定与 chargeRecords 一致：输入接受字符串（来自输入框），
/// 任何非法输入返回 null / 空值，绝不抛错。
library;

import 'package:ev_tool_app/core/domain/charge_records.dart'
    hide vehicleNameMaxLength;
import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/domain/vehicles.dart';

/// 备注最大长度（与表单 maxlength 一致；独立声明，保持模块自洽）
const int expenseNoteMaxLength = 100;

/// 支出类型元信息
class ExpenseTypeMeta {
  const ExpenseTypeMeta({required this.label, required this.icon});

  /// 展示文案
  final String label;

  /// Material 图标名（码点表中已有）
  final String icon;
}

/// 支出类型枚举（存储 key，顺序即表单/筛选展示顺序）
const List<String> expenseTypes = <String>[
  'insurance',
  'parking',
  'wash',
  'maintenance',
  'toll',
  'fine',
  'parts',
  'other',
];

/// 支出类型元信息表
// ignore: constant_identifier_names
const Map<String, ExpenseTypeMeta> EXPENSE_TYPE_META =
    <String, ExpenseTypeMeta>{
      'insurance': ExpenseTypeMeta(label: 'Insurance', icon: 'verified_user'),
      'parking': ExpenseTypeMeta(label: 'Parking', icon: 'place'),
      'wash': ExpenseTypeMeta(label: 'Car Wash', icon: 'water_drop'),
      'maintenance': ExpenseTypeMeta(
        label: 'Maintenance & Repair',
        icon: 'build',
      ),
      'toll': ExpenseTypeMeta(label: 'Tolls', icon: 'speed'),
      'fine': ExpenseTypeMeta(label: 'Fines', icon: 'warning'),
      'parts': ExpenseTypeMeta(label: 'Parts & Accessories', icon: 'settings'),
      'other': ExpenseTypeMeta(label: 'Other', icon: 'payments'),
    };

/// 时间范围预设 key 列表（列表页筛选顺序）
const List<String> timeRangePresets = <String>[
  'month',
  'quarter3',
  'year',
  'all',
];

/// 时间范围预设展示文案
const Map<String, String> timeRangeLabels = <String, String>{
  'month': 'This Month',
  'quarter3': 'Last 3 Months',
  'year': 'This Year',
  'all': 'All',
};

/// 综合报表中充电分项的 key（与 EXPENSE_TYPES 同层参与占比）
const String chargeTypeKey = 'charge';

/// 综合报表中充电分项的展示文案
const String chargeTypeLabel = 'Charging';

/// 养车支出记录（不可变；vehicleName 存快照，车辆改名/删除不影响历史记录展示）
class Expense {
  const Expense({
    required this.id,
    required this.type,
    required this.date,
    required this.amount,
    required this.note,
    required this.vehicleId,
    required this.vehicleName,
    required this.createdAt,
  });

  /// 存储脏数据守卫（任一核心字段非法返回 null，绝不抛错）
  static Expense? fromJson(Map<String, dynamic>? json) =>
      normalizeStoredExpense(json);

  /// 记录 id
  final String id;

  /// 支出类型（见 [expenseTypes]）
  final String type;

  /// 日期 "YYYY-MM-DD"
  final String date;

  /// 金额（元，两位小数）
  final double amount;

  /// 备注
  final String note;

  /// 关联车辆 id（存量记录无车辆字段 → null，展示端按 null 隐藏）
  final String? vehicleId;

  /// 关联车辆昵称快照
  final String? vehicleName;

  /// 创建时间戳（毫秒）
  final int createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type,
    'date': date,
    'amount': amount,
    'note': note,
    'vehicleId': vehicleId,
    'vehicleName': vehicleName,
    'createdAt': createdAt,
  };

  /// 返回仅替换部分字段的新支出（不可变）
  Expense copyWith({
    String? id,
    String? type,
    String? date,
    double? amount,
    String? note,
    String? vehicleId,
    String? vehicleName,
    int? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleName: vehicleName ?? this.vehicleName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 支出表单数据（amount 接受字符串；车辆字段可选；note 选填不参与致命校验）
class ExpenseForm {
  const ExpenseForm({
    this.type,
    this.date,
    this.amount,
    this.note,
    this.vehicleId,
    this.vehicleName,
  });

  /// 支出类型
  final Object? type;

  /// 日期 "YYYY-MM-DD"
  final Object? date;

  /// 金额（元）
  final Object? amount;

  /// 备注
  final Object? note;

  /// 关联车辆 id
  final Object? vehicleId;

  /// 关联车辆昵称快照
  final Object? vehicleName;
}

/// 支出类型是否在枚举内
bool _isKnownType(Object? value) =>
    value is String && expenseTypes.contains(value);

/// JS String(value ?? "") 的等价转换（null → ""）
String _stringify(Object? value) => value == null ? '' : value.toString();

/// JS String.slice(0, maxLength)：按 UTF-16 码元截断
String _truncate(String value, int maxLength) {
  return value.length <= maxLength ? value : value.substring(0, maxLength);
}

/// JS 真值判定（null / false / 0 / NaN / "" 为假）
bool _isTruthy(Object? value) {
  if (value == null) {
    return false;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return !value.isNaN && value != 0;
  }
  if (value is String) {
    return value.isNotEmpty;
  }
  return true;
}

/// 表单数据 → 规范养车支出记录
///
/// type/date/amount 任一非法返回 null。
Expense? buildExpenseFromForm(ExpenseForm? form, int now) {
  final source = form ?? const ExpenseForm();
  if (!_isKnownType(source.type)) {
    return null;
  }
  if (!isValidDateString(source.date)) {
    return null;
  }
  final amount = toNumber(source.amount);
  if (amount == null || amount <= 0) {
    return null;
  }
  final vehicleId = _isTruthy(source.vehicleId)
      ? source.vehicleId.toString()
      : null;
  return Expense(
    id: generateId(nowMs: now),
    type: source.type as String,
    date: source.date as String,
    amount: toYuan(amount),
    note: _truncate(_stringify(source.note).trim(), expenseNoteMaxLength),
    vehicleId: vehicleId,
    vehicleName: _isTruthy(source.vehicleName)
        ? _truncate(source.vehicleName.toString().trim(), vehicleNameMaxLength)
        : null,
    createdAt: now,
  );
}

/// 存储记录守卫：校验并按字段白名单拷贝（不透传未知字段）
///
/// 任一核心字段非法返回 null。
Expense? normalizeStoredExpense(Map<String, dynamic>? raw) {
  if (raw == null || !_isTruthy(raw['id'])) {
    return null;
  }
  if (!_isKnownType(raw['type'])) {
    return null;
  }
  if (!isValidDateString(raw['date'])) {
    return null;
  }
  final amount = toNumber(raw['amount']);
  if (amount == null || amount <= 0) {
    return null;
  }
  final rawVehicleId = raw['vehicleId'];
  final rawVehicleName = raw['vehicleName'];
  return Expense(
    id: raw['id'].toString(),
    type: raw['type'] as String,
    date: raw['date'] as String,
    amount: toYuan(amount),
    /* 存量记录无车辆字段 → null，展示端按 null 隐藏 */
    note: _truncate(_stringify(raw['note']), expenseNoteMaxLength),
    vehicleId: rawVehicleId is String && rawVehicleId.isNotEmpty
        ? rawVehicleId
        : null,
    vehicleName: rawVehicleName is String && rawVehicleName.trim().isNotEmpty
        ? _truncate(rawVehicleName.trim(), vehicleNameMaxLength)
        : null,
    createdAt: _timestampOrZero(raw['createdAt']),
  );
}

/// 时间戳守卫：非法 / 0 归 0（与 JS toNumber(x) || 0 同口径）
int _timestampOrZero(Object? value) {
  final num = toNumber(value);
  if (num == null || num == 0) {
    return 0;
  }
  return jsRound(num).toInt();
}

/// 支出排序：日期降序，同日按 createdAt 降序（新记录在前）
///
/// 返回新数组（不改原数组）；非数组输入返回 []。
List<Expense> sortExpensesDesc(List<Expense>? expenses) {
  if (expenses == null) {
    return const <Expense>[];
  }
  final sorted = List<Expense>.of(expenses);
  sorted.sort((a, b) {
    if (a.date != b.date) {
      return b.date.compareTo(a.date);
    }
    return b.createdAt.compareTo(a.createdAt);
  });
  return sorted;
}

/// 时间范围（resolveTimeRange 输出；end 恒为 null：表单日期选择器
/// end=今天，不存在未来日期，无需上界）
class TimeRange {
  const TimeRange({required this.preset, this.start, this.end});

  /// 预设 key："month"|"quarter3"|"year"|"all"
  final String preset;

  /// 起始日期 "YYYY-MM-DD"（all 时为 null）
  final String? start;

  /// 截止日期（恒为 null）
  final String? end;
}

/// 时间范围预设 → 起始日期
///
/// month → 当月 1 日；quarter3 → 前 2 个月的 1 日（含当月共三个月）；
/// year → 当年 1 月 1 日。all 或未知预设 → 双 null。
TimeRange resolveTimeRange(String? preset, {DateTime? now}) {
  final current = now ?? DateTime.now();
  switch (preset) {
    case 'month':
      return TimeRange(
        preset: 'month',
        start: '${current.year}-${pad2(current.month)}-01',
      );
    case 'quarter3':
      final startKey = shiftMonthKey(
        '${current.year}-${pad2(current.month)}',
        -2,
      );
      return TimeRange(
        preset: 'quarter3',
        start: startKey == null ? null : '$startKey-01',
      );
    case 'year':
      return TimeRange(preset: 'year', start: '${current.year}-01-01');
    case 'all':
      return const TimeRange(preset: 'all');
    default:
      return const TimeRange(preset: 'all');
  }
}

/// 日期是否落在时间范围内（含边界；零填充 ISO 日期字符串字典序比较）
///
/// range 为 null → true；dateStr 非法 → false。
bool isDateInRange(Object? dateStr, TimeRange? range) {
  if (range == null) {
    return true;
  }
  if (!isValidDateString(dateStr)) {
    return false;
  }
  if (range.start != null && (dateStr as String).compareTo(range.start!) < 0) {
    return false;
  }
  if (range.end != null && (dateStr as String).compareTo(range.end!) > 0) {
    return false;
  }
  return true;
}

/// 组合筛选条件（列表页时间/类型/车辆 + 报表页月份/年份复用同一入口）
class ExpenseFilters {
  const ExpenseFilters({
    this.range,
    this.monthKey,
    this.year,
    this.type,
    this.vehicleId,
  });

  /// 时间范围（resolveTimeRange 输出）
  final TimeRange? range;

  /// 月份 key "YYYY-MM"（null 不过滤）
  final String? monthKey;

  /// 年份 "YYYY"（null 不过滤）
  final String? year;

  /// 支出类型；为其他值视为无匹配（返回 []，与 filterRecords 契约一致）
  final Object? type;

  /// 车辆 id
  final String? vehicleId;
}

/// 组合筛选支出（返回新数组，保持原顺序；非数组输入返回 []）
List<Expense> filterExpenses(List<Expense>? expenses, ExpenseFilters? filters) {
  if (expenses == null) {
    return const <Expense>[];
  }
  final filter = filters ?? const ExpenseFilters();
  final type = filter.type;
  if (type != null && !_isKnownType(type)) {
    return const <Expense>[];
  }
  final typeText = type is String ? type : null;
  return <Expense>[
    for (final expense in expenses)
      if (_matchesFilters(expense, filter, typeText)) expense,
  ];
}

bool _matchesFilters(Expense expense, ExpenseFilters filter, String? typeText) {
  if (filter.range != null && !isDateInRange(expense.date, filter.range)) {
    return false;
  }
  if (filter.monthKey != null &&
      filter.monthKey!.isNotEmpty &&
      getMonthKey(expense.date) != filter.monthKey) {
    return false;
  }
  if (filter.year != null &&
      filter.year!.isNotEmpty &&
      expense.date.length >= 4 &&
      expense.date.substring(0, 4) != filter.year) {
    return false;
  }
  if (_isTruthy(typeText) && expense.type != typeText) {
    return false;
  }
  if (_isTruthy(filter.vehicleId) && expense.vehicleId != filter.vehicleId) {
    return false;
  }
  return true;
}

/// 分类型小计
class ExpenseTypeBucket {
  const ExpenseTypeBucket({required this.count, required this.totalAmount});

  /// 条数
  final int count;

  /// 金额小计（两位小数）
  final double totalAmount;

  @override
  bool operator ==(Object other) {
    return other is ExpenseTypeBucket &&
        other.count == count &&
        other.totalAmount == totalAmount;
  }

  @override
  int get hashCode => Object.hash(count, totalAmount);
}

/// 支出汇总结果
class ExpenseSummary {
  const ExpenseSummary({
    required this.count,
    required this.totalAmount,
    required this.byType,
  });

  /// 有效支出条数
  final int count;

  /// 金额合计（两位小数）
  final double totalAmount;

  /// 分类型小计（仅含有数据的类型）
  final Map<String, ExpenseTypeBucket> byType;

  @override
  bool operator ==(Object other) {
    return other is ExpenseSummary &&
        other.count == count &&
        other.totalAmount == totalAmount &&
        _mapEquals(other.byType, byType);
  }

  @override
  int get hashCode => Object.hash(count, totalAmount);
}

bool _mapEquals(
  Map<String, ExpenseTypeBucket> a,
  Map<String, ExpenseTypeBucket> b,
) {
  if (a.length != b.length) {
    return false;
  }
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

/// 支出汇总（金额为正数且类型合法才计入）
///
/// 空结果：`ExpenseSummary(count: 0, totalAmount: 0, byType: {})`。
ExpenseSummary calcExpenseSummary(List<Expense>? expenses) {
  if (expenses == null) {
    return const ExpenseSummary(
      count: 0,
      totalAmount: 0,
      byType: <String, ExpenseTypeBucket>{},
    );
  }
  var count = 0;
  final byType = <String, ExpenseTypeBucket>{};
  for (final expense in expenses) {
    final amount = toNumber(expense.amount);
    if (amount == null || amount <= 0 || !_isKnownType(expense.type)) {
      continue;
    }
    count += 1;
    final previous =
        byType[expense.type] ??
        const ExpenseTypeBucket(count: 0, totalAmount: 0);
    byType[expense.type] = ExpenseTypeBucket(
      count: previous.count + 1,
      totalAmount: toYuan(previous.totalAmount + amount),
    );
  }
  var totalAmount = 0.0;
  for (final bucket in byType.values) {
    totalAmount += bucket.totalAmount;
  }
  return ExpenseSummary(
    count: count,
    totalAmount: toYuan(totalAmount),
    byType: byType,
  );
}

/// 充电 + 养车合并汇总（报表页数据源，输入由页面预先按周期/车辆过滤）
///
/// 充电记录只取 cost 为正数的（不校验 energy），整体归入
/// byType[chargeTypeKey]；total = chargeTotal + expenseTotal（两位小数）。
CombinedSummary calcCombinedSummary(
  List<ChargeRecord>? records,
  List<Expense>? expenses,
) {
  var chargeCount = 0;
  var chargeTotal = 0.0;
  final byType = <String, ExpenseTypeBucket>{};
  if (records != null) {
    for (final record in records) {
      final cost = toNumber(record.cost);
      if (cost == null || cost <= 0) {
        continue;
      }
      chargeCount += 1;
      chargeTotal += cost;
    }
  }
  chargeTotal = toYuan(chargeTotal);
  if (chargeCount > 0) {
    byType[chargeTypeKey] = ExpenseTypeBucket(
      count: chargeCount,
      totalAmount: chargeTotal,
    );
  }

  final expenseSummary = calcExpenseSummary(expenses);
  for (final entry in expenseSummary.byType.entries) {
    byType[entry.key] = entry.value;
  }
  return CombinedSummary(
    chargeCount: chargeCount,
    chargeTotal: chargeTotal,
    expenseCount: expenseSummary.count,
    expenseTotal: expenseSummary.totalAmount,
    byType: byType,
    total: toYuan(chargeTotal + expenseSummary.totalAmount),
  );
}

/// 充电 + 养车合并汇总结果
class CombinedSummary {
  const CombinedSummary({
    required this.chargeCount,
    required this.chargeTotal,
    required this.expenseCount,
    required this.expenseTotal,
    required this.byType,
    required this.total,
  });

  /// 充电条数
  final int chargeCount;

  /// 充电金额合计（两位小数）
  final double chargeTotal;

  /// 养车支出条数
  final int expenseCount;

  /// 养车支出金额合计（两位小数）
  final double expenseTotal;

  /// 分项小计（charge + 各支出类型）
  final Map<String, ExpenseTypeBucket> byType;

  /// 周期总花费 = chargeTotal + expenseTotal（两位小数）
  final double total;
}

/// 分项占比条目（降序），供报表占比条与图例渲染
class TypeBreakdownItem {
  const TypeBreakdownItem({
    required this.key,
    required this.label,
    required this.count,
    required this.totalAmount,
    required this.percent,
  });

  /// 分项 key（charge 或支出类型）
  final String key;

  /// 展示文案
  final String label;

  /// 条数
  final int count;

  /// 金额小计（两位小数）
  final double totalAmount;

  /// 占比（Math.round(金额 / total * 100)，四舍五入后合计可能为 99%/101%）
  final int percent;
}

/// 分项占比列表（按金额降序）
List<TypeBreakdownItem> sortTypeBreakdown(CombinedSummary? summary) {
  final source = summary?.byType ?? const <String, ExpenseTypeBucket>{};
  final total = toNumber(summary?.total) ?? 0;
  final items = <TypeBreakdownItem>[
    for (final entry in source.entries)
      TypeBreakdownItem(
        key: entry.key,
        label: entry.key == chargeTypeKey
            ? chargeTypeLabel
            : EXPENSE_TYPE_META[entry.key]?.label ?? entry.key,
        count: entry.value.count,
        totalAmount: toYuan(entry.value.totalAmount),
        percent: total > 0
            ? jsRound(entry.value.totalAmount / total * 100).toInt()
            : 0,
      ),
  ];
  items.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  return items;
}

/// 文字小结中最多点名的分项数，其余合并为「其他」
const int _reportTopN = 3;

/// 报表文字小结
///
/// total ≤ 0 → "{periodLabel} · No expenses yet"；
/// 否则如 "This year · Total maintenance spend: $4,860.00;
/// Charging 42%, Insurance 35%, Parking 15%"。
String buildReportTextLine(
  List<TypeBreakdownItem>? breakdown,
  Object? total, {
  String? periodLabel,
}) {
  final prefix = periodLabel ?? '';
  final lead = prefix.isEmpty ? '' : '$prefix · ';
  final totalNum = toNumber(total) ?? 0;
  if (totalNum <= 0) {
    return '${lead}No expenses yet';
  }
  final items = breakdown ?? const <TypeBreakdownItem>[];
  final top = items.take(_reportTopN).toList(growable: false);
  final rest = items.skip(_reportTopN).toList(growable: false);
  var restPercent = 0;
  for (final item in rest) {
    restPercent += item.percent;
  }
  final parts = <String>[
    for (final item in top) '${item.label} ${item.percent}%',
  ];
  if (rest.isNotEmpty && restPercent > 0) {
    parts.add('Other $restPercent%');
  }
  return '${lead}Total maintenance spend: ${formatMoney(totalNum)}; '
      '${parts.join(', ')}';
}

/// 最高单笔支出
class TopExpense {
  const TopExpense({required this.amount, required this.typeLabel});

  /// 金额（两位小数）
  final double amount;

  /// 类型展示文案
  final String typeLabel;

  @override
  bool operator ==(Object other) {
    return other is TopExpense &&
        other.amount == amount &&
        other.typeLabel == typeLabel;
  }

  @override
  int get hashCode => Object.hash(amount, typeLabel);
}

/// 金额最大的一笔支出（列表页「最高单笔」指标）
///
/// 无有效支出返回 null。
TopExpense? pickTopExpense(List<Expense>? expenses) {
  if (expenses == null) {
    return null;
  }
  String? topType;
  var topAmount = 0.0;
  for (final expense in expenses) {
    final amount = toNumber(expense.amount);
    if (amount == null || amount <= 0 || !_isKnownType(expense.type)) {
      continue;
    }
    if (topType == null || amount > topAmount) {
      topType = expense.type;
      topAmount = amount.toDouble();
    }
  }
  if (topType == null) {
    return null;
  }
  return TopExpense(
    amount: toYuan(topAmount),
    typeLabel:
        (EXPENSE_TYPE_META[topType] ?? EXPENSE_TYPE_META['other'])!.label,
  );
}

/// 年度逐月合并总花费（月度趋势柱状图数据点）
class MonthlyTotal {
  const MonthlyTotal({
    required this.monthKey,
    required this.count,
    required this.totalCost,
  });

  /// 月份 key "YYYY-MM"
  final String monthKey;

  /// 当月条数（充电 + 养车）
  final int count;

  /// 当月总花费（充电 cost + 养车 amount，两位小数）
  final double totalCost;

  @override
  bool operator ==(Object other) {
    return other is MonthlyTotal &&
        other.monthKey == monthKey &&
        other.count == count &&
        other.totalCost == totalCost;
  }

  @override
  int get hashCode => Object.hash(monthKey, count, totalCost);
}

/// 年度逐月合并总花费（报表页月度趋势柱状图，充电 cost + 养车 amount）
///
/// 输出形状兼容 annualReport.calcBarPercents（读 totalCost），
/// 固定 12 项保证渲染结构稳定（1-12 月顺序）。
List<MonthlyTotal> calcCombinedMonthlyTotals(
  List<ChargeRecord>? records,
  List<Expense>? expenses,
  Object? year,
) {
  final yearStr = year?.toString() ?? '';
  final months = <MonthlyTotal>[
    for (var month = 1; month <= 12; month += 1)
      MonthlyTotal(monthKey: '$yearStr-${pad2(month)}', count: 0, totalCost: 0),
  ];
  final index = <String, int>{
    for (var i = 0; i < months.length; i += 1) months[i].monthKey: i,
  };
  for (final record in records ?? const <ChargeRecord>[]) {
    _accumulateMonth(months, index, record.date, toNumber(record.cost));
  }
  for (final expense in expenses ?? const <Expense>[]) {
    _accumulateMonth(months, index, expense.date, toNumber(expense.amount));
  }
  return months;
}

void _accumulateMonth(
  List<MonthlyTotal> months,
  Map<String, int> index,
  String date,
  num? value,
) {
  if (value == null || value <= 0) {
    return;
  }
  final monthKey = getMonthKey(date);
  final i = monthKey == null ? null : index[monthKey];
  if (i == null) {
    return;
  }
  final current = months[i];
  months[i] = MonthlyTotal(
    monthKey: current.monthKey,
    count: current.count + 1,
    totalCost: toYuan(current.totalCost + value),
  );
}

/// 日期全格式（表单行展示；历史函数名保留）
///
/// "2026-08-28" → "Aug 28, 2026"；非法返回 ""。
String formatDateCn(Object? dateStr) {
  return formatFullDate(dateStr);
}

/// 车辆改名：同步刷新关联支出的 vehicleName 快照
///
/// 昵称走与 normalizeStoredExpense 相同的 trim/截断守卫；
/// 返回新数组（不改原数组）；非数组输入返回 []。
List<Expense> applyVehicleSnapshotRename(
  List<Expense>? expenses,
  dynamic vehicleId,
  dynamic nextName,
) {
  if (expenses == null || !_isTruthy(vehicleId)) {
    return expenses == null ? const <Expense>[] : List<Expense>.of(expenses);
  }
  final id = vehicleId.toString();
  final name = _truncate(
    (nextName ?? '').toString().trim(),
    vehicleNameMaxLength,
  );
  return <Expense>[
    for (final expense in expenses)
      expense.vehicleId == id ? expense.copyWith(vehicleName: name) : expense,
  ];
}

/// 车辆删除：关联支出清除车辆字段（vehicleId/vehicleName → null）
///
/// 返回新数组（不改原数组）；非数组输入返回 []。
List<Expense> applyVehicleSnapshotRemoval(
  List<Expense>? expenses,
  dynamic vehicleId,
) {
  if (expenses == null || !_isTruthy(vehicleId)) {
    return expenses == null ? const <Expense>[] : List<Expense>.of(expenses);
  }
  final id = vehicleId.toString();
  return <Expense>[
    for (final expense in expenses)
      expense.vehicleId == id
          ? Expense(
              id: expense.id,
              type: expense.type,
              date: expense.date,
              amount: expense.amount,
              note: expense.note,
              vehicleId: null,
              vehicleName: null,
              createdAt: expense.createdAt,
            )
          : expense,
  ];
}

/// 车辆改名（applyVehicleSnapshotRename 的领域别名）
List<Expense> applyVehicleRename(
  List<Expense>? expenses,
  dynamic vehicleId,
  dynamic nextName,
) {
  return applyVehicleSnapshotRename(expenses, vehicleId, nextName);
}

/// 车辆删除（applyVehicleSnapshotRemoval 的领域别名）
List<Expense> applyVehicleRemoval(List<Expense>? expenses, dynamic vehicleId) {
  return applyVehicleSnapshotRemoval(expenses, vehicleId);
}
