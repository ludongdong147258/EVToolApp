/// 充电年度报告（纯函数）
///
/// 移植自 EVTool 小程序 src/lib/annualReport.js。
/// 年度维度的聚合视图：可用年份、年度报表（总览/逐月/充电方式占比/年度之最）、
/// 月度柱状图高度归一化。聚合口径复用 chargeRecords 的月度/累计汇总
/// （只有 cost 与 energy 均为正数的记录才计入）。
library;

import 'dart:math' as math;

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';

/// 柱状图最小可见高度（百分比），有费用但占比过小的月份钳制到该值
const int minBarPercent = 4;

/// 有充电记录的年份列表
///
/// 降序去重的年份；空/非数组/无合法日期 → []。
List<int> getAvailableYears(List<ChargeRecord>? records) {
  if (records == null) {
    return const <int>[];
  }
  final years = <int>{};
  for (final record in records) {
    final monthKey = getMonthKey(record.date);
    if (monthKey != null) {
      years.add(int.parse(monthKey.substring(0, 4)));
    }
  }
  final sorted = years.toList()..sort((a, b) => b.compareTo(a));
  return sorted;
}

/// 年度报表（一次算全，页面 render 直接消费）
class AnnualReport {
  const AnnualReport({
    required this.year,
    required this.count,
    required this.totalCost,
    required this.totalEnergy,
    required this.costPerKwh,
    required this.months,
    required this.fast,
    required this.home,
    required this.topMonth,
    required this.maxCostRecord,
    required this.maxEnergyRecord,
  });

  /// 目标年份（非法输入返回空报表时为 null）
  final int? year;

  /// 有效记录条数
  final int count;

  /// 总花费（元，两位小数）
  final double totalCost;

  /// 总电量（kWh，两位小数）
  final double totalEnergy;

  /// 度电成本（元/kWh，两位小数；无有效记录为 null）
  final double? costPerKwh;

  /// 逐月汇总（固定 12 项，保证渲染结构稳定）
  final List<MonthSummary> months;

  /// 快充汇总
  final TotalSummary fast;

  /// 家充汇总
  final TotalSummary home;

  /// 最活跃月（并列比 totalCost，再并列保留更早月份；无记录为 null）
  final MonthSummary? topMonth;

  /// 单笔花费最高记录（cost/energy 均正才计入）
  final ChargeRecord? maxCostRecord;

  /// 单笔电量最高记录
  final ChargeRecord? maxEnergyRecord;
}

/// 空报表（months 仍为 12 项全 0，保证渲染结构稳定）
AnnualReport _buildEmptyReport(int? year) {
  final yearStr = year?.toString() ?? '0000';
  return AnnualReport(
    year: year,
    count: 0,
    totalCost: 0,
    totalEnergy: 0,
    costPerKwh: null,
    months: <MonthSummary>[
      for (var month = 1; month <= 12; month += 1)
        MonthSummary(
          monthKey: '$yearStr-${pad2(month)}',
          count: 0,
          totalCost: 0,
          totalEnergy: 0,
          costPerKwh: null,
        ),
    ],
    fast: const TotalSummary(
      count: 0,
      totalCost: 0,
      totalEnergy: 0,
      costPerKwh: null,
    ),
    home: const TotalSummary(
      count: 0,
      totalCost: 0,
      totalEnergy: 0,
      costPerKwh: null,
    ),
    topMonth: null,
    maxCostRecord: null,
    maxEnergyRecord: null,
  );
}

/// 候选月是否应取代当前最活跃月：次数多者胜；并列比 totalCost；
/// 再并列保留更早月份（> 严格比较，不替换）
bool _isBetterTopMonth(MonthSummary candidate, MonthSummary current) {
  if (candidate.count != current.count) {
    return candidate.count > current.count;
  }
  return candidate.totalCost > current.totalCost;
}

/// 年度报表（一次算全，页面 render 直接消费）
///
/// 非法输入（非数组 / year 非整数）返回空报表（year 为 null）。
AnnualReport calcAnnualReport(List<ChargeRecord>? records, Object? year) {
  if (records == null || year is! int) {
    return _buildEmptyReport(null);
  }

  final yearStr = year.toString();
  final yearRecords = <ChargeRecord>[
    for (final record in records)
      if (getMonthKey(record.date)?.substring(0, 4) == yearStr) record,
  ];
  final months = <MonthSummary>[
    for (var month = 1; month <= 12; month += 1)
      calcMonthSummary(yearRecords, '$yearStr-${pad2(month)}'),
  ];

  MonthSummary? topMonth;
  for (final month in months) {
    if (month.count > 0 &&
        (topMonth == null || _isBetterTopMonth(month, topMonth))) {
      topMonth = month;
    }
  }

  /* 单次之最：与汇总同口径（cost/energy 均正），严格 > 保留并列中日期更晚者 */
  ChargeRecord? maxCostRecord;
  ChargeRecord? maxEnergyRecord;
  for (final record in yearRecords) {
    final cost = toNumber(record.cost);
    final energy = toNumber(record.energy);
    if (cost == null || cost <= 0 || energy == null || energy <= 0) {
      continue;
    }
    final maxCost = maxCostRecord == null ? null : toNumber(maxCostRecord.cost);
    if (maxCostRecord == null || cost > (maxCost ?? 0)) {
      maxCostRecord = record;
    }
    final maxEnergy = maxEnergyRecord == null
        ? null
        : toNumber(maxEnergyRecord.energy);
    if (maxEnergyRecord == null || energy > (maxEnergy ?? 0)) {
      maxEnergyRecord = record;
    }
  }

  final total = calcTotalSummary(yearRecords);
  return AnnualReport(
    year: year,
    count: total.count,
    totalCost: total.totalCost,
    totalEnergy: total.totalEnergy,
    costPerKwh: total.costPerKwh,
    months: months,
    fast: calcTotalSummary(<ChargeRecord>[
      for (final record in yearRecords)
        if (record.type == 'fast') record,
    ]),
    home: calcTotalSummary(<ChargeRecord>[
      for (final record in yearRecords)
        if (record.type == 'home') record,
    ]),
    topMonth: topMonth,
    maxCostRecord: maxCostRecord,
    maxEnergyRecord: maxEnergyRecord,
  );
}

/// 12 个月柱高百分比（0-100 整数）
///
/// 最大 totalCost 月为 100，其余按比例四舍五入；
/// 有费用但结果小于 [minBarPercent] 时钳制到 [minBarPercent]；
/// 非数组或长度不为 12 → 12 个 0。
List<int> calcBarPercents(List<MonthSummary>? months) {
  if (months == null || months.length != 12) {
    return List<int>.filled(12, 0, growable: false);
  }
  var maxCost = 0.0;
  for (final month in months) {
    if (month.totalCost > maxCost) {
      maxCost = month.totalCost;
    }
  }
  if (maxCost <= 0) {
    return List<int>.filled(12, 0, growable: false);
  }
  return <int>[
    for (final month in months)
      month.totalCost <= 0
          ? 0
          : math
                .max(
                  minBarPercent,
                  jsRound(month.totalCost / maxCost * 100).toInt(),
                )
                .toInt(),
  ];
}
