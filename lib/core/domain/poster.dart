import 'package:ev_tool_app/core/domain/annual_report.dart';
import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/domain/user_badges.dart';

/// 年度报告分享海报（纯函数，移植小程序 src/lib/poster.js）。
///
/// 只负责「报表 → 绘制模型」的数据整形与布局常量；
/// 绘制由年度报告页的 RepaintBoundary widget 完成（Phase 5）。

/// 海报画布布局（设计 px，绘制时按 dpr 放大）。
const PosterLayout posterLayout = PosterLayout(
  width: 750,
  height: 1570,
  padding: 48,
  heroTop: 120,
  heroHeight: 480,
  splitTop: 660,
  barChartTop: 840,
  barChartHeight: 200,
  bestTop: 1195,
  bestItemHeight: 72,
  footerTop: 1520,
);

class PosterLayout {
  const PosterLayout({
    required this.width,
    required this.height,
    required this.padding,
    required this.heroTop,
    required this.heroHeight,
    required this.splitTop,
    required this.barChartTop,
    required this.barChartHeight,
    required this.bestTop,
    required this.bestItemHeight,
    required this.footerTop,
  });

  final int width;
  final int height;
  final int padding;

  /// 渐变 Hero 区顶部 y。
  final int heroTop;

  /// 渐变 Hero 区高度。
  final int heroHeight;

  /// 充电方式占比分区顶部 y。
  final int splitTop;

  /// 12 月柱状图分区顶部 y。
  final int barChartTop;
  final int barChartHeight;

  /// 年度之最分区顶部 y。
  final int bestTop;

  /// 年度之最单条行高（含间距）。
  final int bestItemHeight;

  /// 底部 slogan 基线。
  final int footerTop;
}

/// 海报单条统计行。
class PosterStatLine {
  const PosterStatLine({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;
}

/// 海报 12 月柱项。
class PosterBar {
  const PosterBar({required this.value, required this.hasRecords});

  /// 原始月费用（2 位小数，归一化/柱顶数值共用）。
  final double value;

  /// 空/实柱判定。
  final bool hasRecords;
}

/// 年度之最条目。
class PosterBestItem {
  const PosterBestItem({
    required this.label,
    required this.value,
    required this.sub,
  });

  final String label;
  final String value;
  final String sub;
}

/// 海报绘制模型（全部为最终文案字符串/数字）。
class PosterModel {
  const PosterModel({
    required this.titleText,
    required this.heroCostText,
    required this.statLines,
    required this.barItems,
    required this.fastPercent,
    required this.homePercent,
    required this.bestItems,
    required this.sloganText,
    required this.footerText,
  });

  final String titleText;
  final String heroCostText;
  final List<PosterStatLine> statLines;
  final List<PosterBar> barItems;
  final int fastPercent;
  final int homePercent;
  final List<PosterBestItem> bestItems;
  final String sloganText;
  final String footerText;
}

/// 多段文案以「 · 」连接（空段跳过，避免悬空分隔符）。
String _joinParts(List<String?> parts) =>
    parts.whereType<String>().where((p) => p.isNotEmpty).join(' · ');

/// 年度之最 → 海报条目（缺数据的条目跳过，全缺时给单条兜底）。
List<PosterBestItem> _buildBestItems(AnnualReport report) {
  final items = <PosterBestItem>[];

  final maxCostRecord = report.maxCostRecord;
  if (maxCostRecord != null) {
    items.add(
      PosterBestItem(
        label: '单次最高花费',
        value: '¥${formatYuan(maxCostRecord.cost)}',
        sub: _joinParts([
          formatRecordDate(maxCostRecord.date),
          typeDefaultTitles[maxCostRecord.type] ?? '充电',
          '${formatYuan(maxCostRecord.energy)}kWh',
        ]),
      ),
    );
  }
  final maxEnergyRecord = report.maxEnergyRecord;
  if (maxEnergyRecord != null) {
    items.add(
      PosterBestItem(
        label: '单次最多电量',
        value: '${formatYuan(maxEnergyRecord.energy)} kWh',
        sub: _joinParts([
          formatRecordDate(maxEnergyRecord.date),
          '¥${formatYuan(maxEnergyRecord.cost)}',
        ]),
      ),
    );
  }
  final topMonth = report.topMonth;
  if (topMonth != null) {
    items.add(
      PosterBestItem(
        label: '最活跃月份',
        value: '${int.tryParse(topMonth.monthKey?.substring(5) ?? '') ?? 0}月',
        sub: '充电 ${topMonth.count} 次 · ¥${formatYuan(topMonth.totalCost)}',
      ),
    );
  }
  if (items.isEmpty) {
    return const [PosterBestItem(label: '年度之最', value: '--', sub: '暂无数据')];
  }
  return items;
}

/// 年度报表 → 海报绘制模型。
///
/// [report] 为 null 时兜底空报表；[totalRecordCount] 为累计充电记录条数
/// （跨年，用于徽标身份文案；缺省/非法时兜底最低档）。
PosterModel buildPosterModel(AnnualReport? report, Object? totalRecordCount) {
  final source = report ?? calcAnnualReport(null, null);
  final count = source.count;
  final fastCount = source.fast.count;
  final fastPercent = count > 0 ? ((fastCount / count) * 100).round() : 0;
  final months = source.months.length == 12
      ? source.months
            .map((m) => PosterBar(value: m.totalCost, hasRecords: m.count > 0))
            .toList()
      : List.generate(12, (_) => const PosterBar(value: 0, hasRecords: false));

  return PosterModel(
    titleText: '${source.year?.toString() ?? '--'} 年度充电报告',
    heroCostText: '¥${formatYuan(source.totalCost)}',
    statLines: [
      PosterStatLine(label: '充电次数', value: '$count', unit: '次'),
      PosterStatLine(
        label: '总电量',
        value: formatYuan(source.totalEnergy),
        unit: 'kWh',
      ),
      PosterStatLine(
        label: '度电均价',
        value: source.costPerKwh == null
            ? '--'
            : formatYuan(source.costPerKwh!),
        unit: '¥/kWh',
      ),
    ],
    barItems: months,
    fastPercent: fastPercent,
    homePercent: count > 0 ? 100 - fastPercent : 0,
    bestItems: _buildBestItems(source),
    // 底部身份文案：徽标（充电达人等）+ 固定 slogan。
    sloganText: '${resolveBadgeLabel(totalRecordCount)} · 电车生活一年一度',
    footerText: 'EVTool 电车充电记录',
  );
}

/// 12 柱高度归一化（与 calcBarPercents 口径一致：按原始月费用归一化）。
///
/// hasRecords=false 恒 0（灰柱由绘制层画）；空输入返回空数组。
List<int> calcPosterBarHeights(
  List<PosterBar>? barItems,
  int maxBarPx,
  int minBarPx,
) {
  if (barItems == null) return [];
  var max = 0.0;
  for (final item in barItems) {
    max = item.value > max ? item.value : max;
  }
  if (max <= 0) {
    return List.filled(barItems.length, 0);
  }
  return [
    for (final item in barItems)
      if (!item.hasRecords || item.value <= 0)
        0
      else
        (((item.value / max) * maxBarPx).round().clamp(minBarPx, maxBarPx)),
  ];
}
