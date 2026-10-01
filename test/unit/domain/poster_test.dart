import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/core/domain/annual_report.dart';
import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/poster.dart';

/// 构造最小年度报表（结构与 calcAnnualReport 输出一致）。
AnnualReport buildReport({Map<String, dynamic> overrides = const {}}) {
  final months = List.generate(12, (i) {
    final overridden = overrides['months'] as List<MonthSummary>?;
    if (overridden != null) return overridden[i];
    return MonthSummary(
      monthKey: '2025-${(i + 1).toString().padLeft(2, '0')}',
      count: i % 2,
      totalCost: (i * 10).toDouble(),
      totalEnergy: (i * 5).toDouble(),
      costPerKwh: null,
    );
  });
  final fast =
      overrides['fast'] as TotalSummary? ??
      const TotalSummary(
        count: 4,
        totalCost: 400,
        totalEnergy: 200,
        costPerKwh: 2,
      );
  final home =
      overrides['home'] as TotalSummary? ??
      const TotalSummary(
        count: 2,
        totalCost: 260,
        totalEnergy: 130,
        costPerKwh: 2,
      );
  return AnnualReport(
    year: overrides['year'] as int? ?? 2025,
    count: overrides['count'] as int? ?? 6,
    totalCost: overrides['totalCost'] as double? ?? 660,
    totalEnergy: overrides['totalEnergy'] as double? ?? 330,
    costPerKwh: overrides.containsKey('costPerKwh')
        ? overrides['costPerKwh'] as double?
        : 2,
    months: months,
    fast: fast,
    home: home,
    topMonth: overrides['topMonth'] as MonthSummary?,
    maxCostRecord: overrides['maxCostRecord'] as ChargeRecord?,
    maxEnergyRecord: overrides['maxEnergyRecord'] as ChargeRecord?,
  );
}

void main() {
  group('POSTER_LAYOUT 布局常量', () {
    test('画布宽高与关键区块位置为常量', () {
      expect(posterLayout.width, 750);
      expect(posterLayout.height, greaterThan(posterLayout.width));
    });

    test('丰富版五分区自上而下互不重叠且都在画布内', () {
      const l = posterLayout;
      expect(l.heroTop + l.heroHeight, lessThan(l.splitTop));
      expect(l.splitTop, lessThan(l.barChartTop));
      expect(l.barChartTop + l.barChartHeight, lessThan(l.bestTop));
      // 年度之最：标题 56px + 最多 3 条
      expect(l.bestTop + 56 + l.bestItemHeight * 3, lessThan(l.footerTop));
      expect(l.footerTop, lessThan(l.height));
    });

    test('柱状图区块（标题 90px + 柱区 + 刻度 36px）不与年度之最重叠', () {
      const l = posterLayout;
      expect(l.barChartTop + 90 + l.barChartHeight + 36, lessThan(l.bestTop));
    });
  });

  group('buildPosterModel 海报绘制模型', () {
    test('标题/大数字/三列指标文案完整', () {
      final model = buildPosterModel(buildReport(), null);
      expect(model.titleText, '2025 年度充电报告');
      expect(model.heroCostText, '¥660.00');
      expect(model.statLines[0].label, '充电次数');
      expect(model.statLines[0].value, '6');
      expect(model.statLines[0].unit, '次');
      expect(model.statLines[1].value, '330.00');
      expect(model.statLines[1].unit, 'kWh');
      expect(model.statLines[2].value, '2.00');
      expect(model.statLines[2].unit, '¥/kWh');
    });

    test('12 个月柱项保留原始费用并以 count 判定空/实柱', () {
      final model = buildPosterModel(buildReport(), null);
      expect(model.barItems, hasLength(12));
      // 奇数下标 count=1（有记录），偶数下标 count=0（空月）
      expect(model.barItems[0].value, 0);
      expect(model.barItems[0].hasRecords, isFalse);
      expect(model.barItems[1].value, 10);
      expect(model.barItems[1].hasRecords, isTrue);
      expect(model.barItems[10].value, 100);
      expect(model.barItems[10].hasRecords, isFalse);
    });

    test('有记录但费用不足 0.5 元的月份仍为实柱（与页面 count>0 口径一致）', () {
      final months = List.generate(12, (i) {
        final base = buildReport().months[i];
        return i == 2
            ? MonthSummary(
                monthKey: base.monthKey,
                count: 1,
                totalCost: 0.4,
                totalEnergy: base.totalEnergy,
                costPerKwh: null,
              )
            : base;
      });
      final model = buildPosterModel(
        buildReport(overrides: {'months': months}),
        null,
      );
      expect(model.barItems[2].value, 0.4);
      expect(model.barItems[2].hasRecords, isTrue);
    });

    test('占比行在无记录时降级为 0%', () {
      final model = buildPosterModel(
        buildReport(
          overrides: {
            'count': 0,
            'fast': const TotalSummary(
              count: 0,
              totalCost: 0,
              totalEnergy: 0,
              costPerKwh: null,
            ),
            'home': const TotalSummary(
              count: 0,
              totalCost: 0,
              totalEnergy: 0,
              costPerKwh: null,
            ),
          },
        ),
        null,
      );
      expect(model.fastPercent, 0);
      expect(model.homePercent, 0);
    });

    test('costPerKwh 为 null 时均价降级为 --', () {
      final model = buildPosterModel(
        buildReport(overrides: {'costPerKwh': null}),
        null,
      );
      expect(model.statLines[2].value, '--');
    });

    test('非法输入不抛错（空模型兜底）', () {
      final model = buildPosterModel(null, null);
      expect(model.titleText, '-- 年度充电报告');
      expect(model.barItems, hasLength(12));
      expect(
        model.barItems.every((i) => i.value == 0 && !i.hasRecords),
        isTrue,
      );
    });

    test('bestItems 输出三条年度之最（含日期/类型/数值格式化）', () {
      final model = buildPosterModel(
        buildReport(
          overrides: {
            'maxCostRecord': ChargeRecord.fromJson(const {
              'id': 'r1',
              'type': 'fast',
              'date': '2025-05-01',
              'cost': 88.5,
              'energy': 50,
              'createdAt': 1,
            }),
            'maxEnergyRecord': ChargeRecord.fromJson(const {
              'id': 'r2',
              'type': 'home',
              'date': '2025-07-12',
              'cost': 60,
              'energy': 75.2,
              'createdAt': 1,
            }),
            'topMonth': const MonthSummary(
              monthKey: '2025-07',
              count: 5,
              totalCost: 200,
              totalEnergy: 0,
              costPerKwh: null,
            ),
          },
        ),
        null,
      );
      expect(model.bestItems, hasLength(3));
      expect(model.bestItems[0].label, '单次最高花费');
      expect(model.bestItems[0].value, '¥88.50');
      expect(
        model.bestItems[0].sub,
        '${formatRecordDate('2025-05-01')} · 快充 · 50.00kWh',
      );
      expect(model.bestItems[1].value, '75.20 kWh');
      expect(
        model.bestItems[1].sub,
        '${formatRecordDate('2025-07-12')} · ¥60.00',
      );
      expect(model.bestItems[2].value, '7月');
      expect(model.bestItems[2].sub, '充电 5 次 · ¥200.00');
    });

    test('年度之最缺省时兜底单条占位（不抛错）', () {
      final model = buildPosterModel(buildReport(), null);
      expect(model.bestItems, hasLength(1));
      expect(model.bestItems[0].label, '年度之最');
      expect(model.bestItems[0].value, '--');
      expect(model.bestItems[0].sub, '暂无数据');
    });

    test('slogan 带徽标身份文案，footer 为产品名落款', () {
      final model = buildPosterModel(buildReport(), null);
      expect(model.sloganText, '见习车主 · 电车生活一年一度');
      expect(model.footerText, 'EVTool 电车充电记录');
    });

    test('slogan 徽标随累计记录条数晋级', () {
      final model = buildPosterModel(buildReport(), 60);
      expect(model.sloganText, '资深车主 · 电车生活一年一度');
    });

    test('累计条数非法时徽标兜底最低档（不抛错）', () {
      final model = buildPosterModel(buildReport(), 'abc');
      expect(model.sloganText, '见习车主 · 电车生活一年一度');
    });
  });

  group('calcPosterBarHeights 柱高归一化', () {
    List<PosterBar> items(List<double> values) =>
        values.map((v) => PosterBar(value: v, hasRecords: v > 0)).toList();

    test('最大值映射到 maxBarPx', () {
      final heights = calcPosterBarHeights(items([0, 50, 100]), 200, 20);
      expect(heights[2], 200);
    });

    test('非零但占比过小的柱钳制到 minBarPx（原始小数不取整）', () {
      final heights = calcPosterBarHeights(items([0.4, 100]), 200, 20);
      expect(heights[0], 20);
    });

    test('hasRecords 为 false 的柱恒为 0（画灰柱由绘制层负责）', () {
      final heights = calcPosterBarHeights(
        [
          const PosterBar(value: 100, hasRecords: true),
          const PosterBar(value: 100, hasRecords: false),
        ],
        200,
        20,
      );
      expect(heights, [200, 0]);
    });

    test('全 0 时全部为 0（不显示柱）', () {
      expect(calcPosterBarHeights(items([0, 0, 0]), 200, 20), [0, 0, 0]);
    });

    test('空数组 / null 输入返回空数组', () {
      expect(calcPosterBarHeights([], 200, 20), isEmpty);
      expect(calcPosterBarHeights(null, 200, 20), isEmpty);
    });
  });
}
