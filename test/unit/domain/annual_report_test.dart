/// annual_report.dart 单测（移植自 src/lib/__tests__/annualReport.test.js）
library;

import 'package:ev_tool_app/core/domain/annual_report.dart';
import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试记录工厂：date/type/cost/energy 必填，其余字段给安全默认值
ChargeRecord mk(String date, String type, double cost, double energy) {
  return ChargeRecord(
    id: '$date-$type-$cost',
    type: type,
    date: date,
    cost: cost,
    energy: energy,
    durationMinutes: null,
    note: '',
    vehicleId: null,
    vehicleName: null,
    createdAt: 0,
  );
}

/// 构造固定 12 项的 months 列表（calcBarPercents 测试用）
List<MonthSummary> monthsOf(double Function(int month) totalCost) {
  return <MonthSummary>[
    for (var month = 1; month <= 12; month += 1)
      MonthSummary(
        monthKey: '2026-${month.toString().padLeft(2, '0')}',
        count: 0,
        totalCost: totalCost(month),
        totalEnergy: 0,
        costPerKwh: null,
      ),
  ];
}

void main() {
  group('getAvailableYears 可用年份', () {
    test('跨年数据返回降序去重的年份列表', () {
      // Arrange
      final records = <ChargeRecord>[
        mk('2026-01-15', 'fast', 30, 40),
        mk('2025-12-31', 'home', 10, 15),
        mk('2026-08-01', 'fast', 50, 60),
        mk('2024-06-01', 'home', 20, 30),
      ];

      // Act
      final years = getAvailableYears(records);

      // Assert
      expect(years, <int>[2026, 2025, 2024]);
    });

    test('空数组 / null 输入返回空数组', () {
      expect(getAvailableYears(<ChargeRecord>[]), isEmpty);
      expect(getAvailableYears(null), isEmpty);
    });

    test('date 非法的记录被忽略，不产生年份', () {
      // Arrange
      final records = <ChargeRecord>[
        mk('2026-03-01', 'fast', 10, 20),
        mk('abc', 'fast', 10, 20),
        mk('', 'home', 10, 20),
      ];

      // Act
      final years = getAvailableYears(records);

      // Assert
      expect(years, <int>[2026]);
    });

    test('单年多条记录只返回一个年份', () {
      final records = <ChargeRecord>[
        mk('2026-02-01', 'fast', 10, 20),
        mk('2026-11-01', 'home', 30, 40),
      ];

      expect(getAvailableYears(records), <int>[2026]);
    });
  });

  group('calcAnnualReport 年度报表', () {
    test('正常汇总：count/费用/电量/度电成本，fast 与 home 之和等于总量', () {
      // Arrange：快充 2 条 + 家充 1 条
      final records = <ChargeRecord>[
        mk('2026-01-10', 'fast', 40, 50),
        mk('2026-03-20', 'fast', 60, 70),
        mk('2026-07-05', 'home', 25, 30),
      ];

      // Act
      final report = calcAnnualReport(records, 2026);

      // Assert
      expect(report.year, 2026);
      expect(report.count, 3);
      expect(report.totalCost, 125);
      expect(report.totalEnergy, 150);
      expect(report.costPerKwh, 0.83);
      expect(report.fast.count, 2);
      expect(report.fast.totalCost, 100);
      expect(report.home.count, 1);
      expect(report.home.totalCost, 25);
      expect(report.fast.count + report.home.count, report.count);
    });

    test('months 固定 12 项且 monthKey 补零，1 月与 12 月记录落在正确桶', () {
      // Arrange：跨年首尾边界
      final records = <ChargeRecord>[
        mk('2026-01-01', 'fast', 10, 20),
        mk('2026-12-31', 'home', 30, 40),
        mk('2026-02-28', 'fast', 20, 30),
      ];

      // Act
      final report = calcAnnualReport(records, 2026);

      // Assert
      expect(report.months.length, 12);
      expect(report.months[0].monthKey, '2026-01');
      expect(report.months[1].monthKey, '2026-02');
      expect(report.months[11].monthKey, '2026-12');
      expect(report.months[0].count, 1);
      expect(report.months[1].count, 1);
      expect(report.months[11].count, 1);
      expect(report.months[2].count, 0);
    });

    test('空记录 / 非数组返回空报表（months 12 项全 0，极值为 null）', () {
      // Arrange & Act
      final reports = <AnnualReport>[
        calcAnnualReport(<ChargeRecord>[], 2026),
        calcAnnualReport(null, 2026),
      ];

      // Assert
      for (final report in reports) {
        expect(report.count, 0);
        expect(report.totalCost, 0);
        expect(report.totalEnergy, 0);
        expect(report.costPerKwh, isNull);
        expect(report.months.length, 12);
        for (final month in report.months) {
          expect(month.count, 0);
        }
        expect(report.topMonth, isNull);
        expect(report.maxCostRecord, isNull);
        expect(report.maxEnergyRecord, isNull);
      }
    });

    test('跨年数据：目标年之外的记录完全不计入', () {
      // Arrange
      final records = <ChargeRecord>[
        mk('2026-05-01', 'fast', 50, 60),
        mk('2025-05-01', 'fast', 999, 999),
        mk('2027-05-01', 'home', 888, 888),
      ];

      // Act
      final report = calcAnnualReport(records, 2026);

      // Assert
      expect(report.count, 1);
      expect(report.totalCost, 50);
      expect(report.maxCostRecord?.id, records[0].id);
      for (var i = 0; i < report.months.length; i += 1) {
        expect(report.months[i].count, i == 4 ? 1 : 0);
      }
    });

    test('非法 year（字符串 / null / 小数）返回空报表且 year 为 null', () {
      // Arrange
      final records = <ChargeRecord>[mk('2026-01-01', 'fast', 10, 20)];

      // Act & Assert
      expect(calcAnnualReport(records, '2026').year, isNull);
      expect(calcAnnualReport(records, null).year, isNull);
      expect(calcAnnualReport(records, 2026.5).year, isNull);
      expect(calcAnnualReport(records, '2026').count, 0);
    });

    test('cost=0 或 energy=0 的记录不计入任何汇总', () {
      // Arrange：normalize 已过滤，此处为防御口径
      final records = <ChargeRecord>[
        mk('2026-04-01', 'fast', 0, 30),
        mk('2026-04-02', 'fast', 20, 0),
        mk('2026-04-03', 'fast', 15, 25),
      ];

      // Act
      final report = calcAnnualReport(records, 2026);

      // Assert
      expect(report.count, 1);
      expect(report.totalCost, 15);
      expect(report.maxCostRecord?.id, records[2].id);
    });

    test('单条记录：topMonth 与两个极值均为该条', () {
      // Arrange
      final records = <ChargeRecord>[mk('2026-09-15', 'fast', 42.5, 55)];

      // Act
      final report = calcAnnualReport(records, 2026);

      // Assert
      expect(report.topMonth?.monthKey, '2026-09');
      expect(report.topMonth?.count, 1);
      expect(report.maxCostRecord?.id, records[0].id);
      expect(report.maxEnergyRecord?.id, records[0].id);
    });

    test('maxCostRecord 与 maxEnergyRecord 各自独立正确', () {
      // Arrange：A 花费高、B 电量高
      final records = <ChargeRecord>[
        mk('2026-02-01', 'fast', 200, 30),
        mk('2026-03-01', 'home', 20, 100),
      ];

      // Act
      final report = calcAnnualReport(records, 2026);

      // Assert
      expect(report.maxCostRecord?.id, records[0].id);
      expect(report.maxCostRecord?.cost, 200);
      expect(report.maxEnergyRecord?.id, records[1].id);
      expect(report.maxEnergyRecord?.energy, 100);
    });

    test('topMonth 并列：次数相同比 totalCost，再并列取更早月份', () {
      // Arrange：1 月与 3 月各 2 次，3 月费用更高 → 3 月胜
      final costTie = <ChargeRecord>[
        mk('2026-01-05', 'fast', 10, 20),
        mk('2026-01-20', 'fast', 10, 20),
        mk('2026-03-05', 'fast', 30, 40),
        mk('2026-03-25', 'fast', 30, 40),
      ];
      // Arrange：次数与费用均相同 → 更早的 1 月胜
      final fullTie = <ChargeRecord>[
        mk('2026-01-05', 'fast', 10, 20),
        mk('2026-03-05', 'fast', 10, 20),
      ];

      // Act
      final tieOnCost = calcAnnualReport(costTie, 2026);
      final tieOnMonth = calcAnnualReport(fullTie, 2026);

      // Assert
      expect(tieOnCost.topMonth?.monthKey, '2026-03');
      expect(tieOnMonth.topMonth?.monthKey, '2026-01');
    });

    test('只有一种 type 时另一 type 汇总全 0', () {
      // Arrange
      final records = <ChargeRecord>[
        mk('2026-06-01', 'home', 10, 20),
        mk('2026-06-15', 'home', 30, 40),
      ];

      // Act
      final report = calcAnnualReport(records, 2026);

      // Assert
      expect(report.fast.count, 0);
      expect(report.fast.totalCost, 0);
      expect(report.home.count, 2);
      expect(report.home.totalCost, 40);
    });
  });

  group('calcBarPercents 柱高归一化', () {
    test('最大费用月为 100，其余按比例取整', () {
      // Arrange：months 按月份序，3 月最大
      final months = monthsOf(
        (month) => month == 3
            ? 200
            : month == 6
            ? 100
            : 0,
      );

      // Act
      final percents = calcBarPercents(months);

      // Assert
      expect(percents.length, 12);
      expect(percents[2], 100);
      expect(percents[5], 50);
      expect(percents[0], 0);
    });

    test('全部月份无费用返回 12 个 0', () {
      expect(calcBarPercents(monthsOf((_) => 0)), List<int>.filled(12, 0));
    });

    test('有费用但占比极小的月份钳制到最小可见高度', () {
      // Arrange：1 元 vs 10000 元，比例取整后为 0
      final months = monthsOf(
        (month) => month == 1
            ? 1
            : month == 2
            ? 10000
            : 0,
      );

      // Act
      final percents = calcBarPercents(months);

      // Assert
      expect(percents[1], 100);
      expect(percents[0], minBarPercent);
    });

    test('非数组 / 长度不为 12 返回 12 个 0', () {
      expect(calcBarPercents(null), List<int>.filled(12, 0));
      expect(calcBarPercents(<MonthSummary>[]), List<int>.filled(12, 0));
      expect(
        calcBarPercents(monthsOf((_) => 1).sublist(0, 11)),
        List<int>.filled(12, 0),
      );
    });
  });
}
