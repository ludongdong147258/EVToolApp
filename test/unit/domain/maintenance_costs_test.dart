/// maintenance_costs.dart 单测
/// （移植自 src/lib/__tests__/maintenanceCosts.test.js，
/// 全部用例逐条对齐，含 vehicles.js 快照同步的补充用例）
library;

import 'package:ev_tool_app/core/domain/charge_records.dart'
    hide
        applyVehicleRename,
        applyVehicleRemoval,
        applyVehicleSnapshotRename,
        applyVehicleSnapshotRemoval,
        vehicleNameMaxLength;
import 'package:ev_tool_app/core/domain/maintenance_costs.dart';
import 'package:ev_tool_app/core/domain/vehicles.dart';
import 'package:flutter_test/flutter_test.dart';

/// 构造一条合法表单数据（个别用例按需覆盖字段）
ExpenseForm buildForm({
  Object? type = 'insurance',
  Object? date = '2026-08-28',
  Object? amount = '199.9',
  Object? note = '人保交强险',
  Object? vehicleId = 'v-1',
  Object? vehicleName = '小电车',
}) {
  return ExpenseForm(
    type: type,
    date: date,
    amount: amount,
    note: note,
    vehicleId: vehicleId,
    vehicleName: vehicleName,
  );
}

/// 可注入的当前时间（2026-08-28；JS 测试 new Date(2026, 7, 28) 月份 0 基）
final DateTime now = DateTime(2026, 8, 28);

/// 构造一条合法存储数据（map 形态，走 normalizeStoredExpense 守卫）
Map<String, dynamic> buildStored([Map<String, dynamic> overrides = const {}]) {
  return <String, dynamic>{
    'id': '1755916800000-483920',
    'type': 'parking',
    'date': '2026-08-20',
    'amount': 15,
    'note': '商场停车',
    'vehicleId': 'v-1',
    'vehicleName': '小电车',
    'createdAt': 1755916800000,
    ...overrides,
  };
}

/// 存储数据 → 规范支出（测试用便捷构造；测试数据非法直接失败）
Expense storedExpense([Map<String, dynamic> overrides = const {}]) {
  final expense = normalizeStoredExpense(buildStored(overrides));
  if (expense == null) {
    fail('测试数据必须通过存储守卫: $overrides');
  }
  return expense;
}

/// 直接构造原始对象形态的支出（不经守卫，模拟 JS 测试的裸对象）
Expense rawExpense({
  String type = 'parking',
  String date = '2026-08-20',
  double amount = 15,
}) {
  return Expense(
    id: 'raw',
    type: type,
    date: date,
    amount: amount,
    note: '',
    vehicleId: null,
    vehicleName: null,
    createdAt: 0,
  );
}

/// 直接构造原始对象形态的充电记录（模拟 JS 测试的裸对象）
ChargeRecord rawRecord(String date, double cost, [double energy = 0]) {
  return ChargeRecord(id: date, date: date, cost: cost, energy: energy);
}

void main() {
  group('buildExpenseFromForm 表单 → 规范记录', () {
    test('合法表单生成规范记录（字符串金额转两位小数）', () {
      // Act
      final record = buildExpenseFromForm(buildForm(), 1755916800000);
      if (record == null) {
        fail('合法表单应生成规范记录');
      }
      // Assert
      expect(record.type, 'insurance');
      expect(record.date, '2026-08-28');
      expect(record.amount, 199.9);
      expect(record.note, '人保交强险');
      expect(record.vehicleId, 'v-1');
      expect(record.vehicleName, '小电车');
      expect(record.createdAt, 1755916800000);
      expect(record.id, startsWith('1755916800000-'));
    });

    test('未知 / 缺省类型返回 null', () {
      expect(buildExpenseFromForm(buildForm(type: 'fuel'), 1), isNull);
      expect(buildExpenseFromForm(buildForm(type: null), 1), isNull);
    });

    test('非法日期返回 null（历法无效 / 格式错误）', () {
      expect(buildExpenseFromForm(buildForm(date: '2026-13-01'), 1), isNull);
      expect(buildExpenseFromForm(buildForm(date: '2026/08/28'), 1), isNull);
    });

    test('金额 ≤0 / NaN / 空返回 null', () {
      expect(buildExpenseFromForm(buildForm(amount: '0'), 1), isNull);
      expect(buildExpenseFromForm(buildForm(amount: '-5'), 1), isNull);
      expect(buildExpenseFromForm(buildForm(amount: 'abc'), 1), isNull);
      expect(buildExpenseFromForm(buildForm(amount: ''), 1), isNull);
    });

    test('note 去首尾空格并截断到 100 字符，空转空串', () {
      final longNote = 'a' * 150;
      final trimmed = buildExpenseFromForm(buildForm(note: '  月保  '), 1);
      final truncated = buildExpenseFromForm(buildForm(note: longNote), 1);
      final empty = buildExpenseFromForm(buildForm(note: '   '), 1);
      expect(trimmed?.note, '月保');
      expect(truncated?.note.length, 100);
      expect(empty?.note, '');
    });

    test('vehicleName 快照去空格并截断到 20 字符，缺省为 null', () {
      final longName = '车' * 30;
      final truncated = buildExpenseFromForm(
        buildForm(vehicleName: longName),
        1,
      );
      final none = buildExpenseFromForm(
        buildForm(vehicleName: '', vehicleId: ''),
        1,
      );
      expect(truncated?.vehicleName?.length, 20);
      expect(none?.vehicleName, isNull);
      expect(none?.vehicleId, isNull);
    });
  });

  group('normalizeStoredExpense 存储守卫', () {
    test('白名单拷贝不透传未知字段', () {
      // Arrange
      final raw = buildStored(<String, dynamic>{
        'extra': 'unknown',
        'cost': 99,
      });
      // Act
      final record = normalizeStoredExpense(raw);
      if (record == null) {
        fail('合法存储数据应通过守卫');
      }
      // Assert
      expect(record.amount, 15);
      expect(record.toJson().keys.toSet(), <String>{
        'id',
        'type',
        'date',
        'amount',
        'note',
        'vehicleId',
        'vehicleName',
        'createdAt',
      });
    });

    test('缺 id / 未知 type / 非法 date / 非法 amount 返回 null', () {
      expect(
        normalizeStoredExpense(<String, dynamic>{
          'type': 'wash',
          'date': '2026-08-01',
          'amount': 1,
        }),
        isNull,
      );
      expect(
        normalizeStoredExpense(buildStored(<String, dynamic>{'type': 'fuel'})),
        isNull,
      );
      expect(
        normalizeStoredExpense(
          buildStored(<String, dynamic>{'date': '2026-13-01'}),
        ),
        isNull,
      );
      expect(
        normalizeStoredExpense(buildStored(<String, dynamic>{'amount': 0})),
        isNull,
      );
      expect(
        normalizeStoredExpense(buildStored(<String, dynamic>{'amount': 'abc'})),
        isNull,
      );
    });

    test('createdAt 缺失补 0；note / vehicleName 走守卫', () {
      // Arrange
      final raw = <String, dynamic>{
        'id': 'x',
        'type': 'wash',
        'date': '2026-08-01',
        'amount': 30,
      };
      // Act
      final record = normalizeStoredExpense(raw);
      if (record == null) {
        fail('合法存储数据应通过守卫');
      }
      // Assert
      expect(record.createdAt, 0);
      expect(record.note, '');
      expect(record.vehicleId, isNull);
      expect(record.vehicleName, isNull);
    });
  });

  group('sortExpensesDesc 排序', () {
    test('日期降序，同日按 createdAt 降序', () {
      // Arrange
      final list = <Expense>[
        storedExpense(<String, dynamic>{'id': 'a', 'date': '2026-08-01'}),
        storedExpense(<String, dynamic>{
          'id': 'b',
          'date': '2026-08-20',
          'createdAt': 1,
        }),
        storedExpense(<String, dynamic>{
          'id': 'c',
          'date': '2026-08-20',
          'createdAt': 2,
        }),
      ];
      // Act
      final sorted = sortExpensesDesc(list);
      // Assert
      expect(sorted.map((item) => item.id).toList(), <String>['c', 'b', 'a']);
    });

    test('非数组返回 []，且不改原数组', () {
      // Arrange
      final list = <Expense>[
        storedExpense(<String, dynamic>{'date': '2026-08-01'}),
        storedExpense(<String, dynamic>{'date': '2026-08-20'}),
      ];
      // Act
      final sorted = sortExpensesDesc(list);
      // Assert
      expect(sortExpensesDesc(null), isEmpty);
      expect(list[0].date, '2026-08-01');
      expect(identical(sorted, list), isFalse);
    });
  });

  group('resolveTimeRange 时间范围预设', () {
    test('month → 当月 1 日；quarter3 → 前 2 个月 1 日；year → 当年 1 月 1 日', () {
      final month = resolveTimeRange('month', now: now);
      final quarter3 = resolveTimeRange('quarter3', now: now);
      final year = resolveTimeRange('year', now: now);
      expect(month.preset, 'month');
      expect(month.start, '2026-08-01');
      expect(month.end, isNull);
      expect(quarter3.preset, 'quarter3');
      expect(quarter3.start, '2026-06-01');
      expect(quarter3.end, isNull);
      expect(year.preset, 'year');
      expect(year.start, '2026-01-01');
      expect(year.end, isNull);
    });

    test('all 与未知预设 → 双 null', () {
      final all = resolveTimeRange('all', now: now);
      final unknown = resolveTimeRange('whatever', now: now);
      expect(all.preset, 'all');
      expect(all.start, isNull);
      expect(all.end, isNull);
      expect(unknown.preset, 'all');
      expect(unknown.start, isNull);
      expect(unknown.end, isNull);
    });

    test('跨年边界：1 月中旬的近三月从前一年 11 月起', () {
      final jan = DateTime(2026, 1, 15);
      final quarter3 = resolveTimeRange('quarter3', now: jan);
      expect(quarter3.start, '2025-11-01');
    });
  });

  group('isDateInRange 范围判断', () {
    // Arrange
    const TimeRange range = TimeRange(preset: 'quarter3', start: '2026-06-01');

    test('含起始边界；早于起始为 false', () {
      expect(isDateInRange('2026-06-01', range), isTrue);
      expect(isDateInRange('2026-05-31', range), isFalse);
    });

    test('range 为 null → true；dateStr 非法 → false', () {
      expect(isDateInRange('2020-01-01', null), isTrue);
      expect(isDateInRange('2026/06/01', range), isFalse);
    });

    test('单边 end 上界包含边界', () {
      const TimeRange bounded = TimeRange(preset: 'x', end: '2026-08-31');
      expect(isDateInRange('2026-08-31', bounded), isTrue);
      expect(isDateInRange('2026-09-01', bounded), isFalse);
    });
  });

  group('filterExpenses 组合筛选', () {
    // Arrange
    final expenses = <Expense>[
      storedExpense(<String, dynamic>{
        'id': 'a',
        'type': 'insurance',
        'date': '2026-08-10',
        'vehicleId': 'v-1',
      }),
      storedExpense(<String, dynamic>{
        'id': 'b',
        'type': 'parking',
        'date': '2026-07-15',
        'vehicleId': 'v-2',
      }),
      storedExpense(<String, dynamic>{
        'id': 'c',
        'type': 'wash',
        'date': '2026-06-01',
        'vehicleId': null,
      }),
    ];

    test('range + type + vehicleId 组合过滤', () {
      final range = resolveTimeRange('quarter3', now: now);
      final filtered = filterExpenses(
        expenses,
        ExpenseFilters(range: range, type: 'parking', vehicleId: 'v-2'),
      );
      expect(filtered.map((item) => item.id).toList(), <String>['b']);
    });

    test('monthKey / year 维度过滤（报表路径）', () {
      final byMonth = filterExpenses(
        expenses,
        const ExpenseFilters(monthKey: '2026-08'),
      );
      expect(byMonth.map((item) => item.id).toList(), <String>['a']);
      expect(
        filterExpenses(expenses, const ExpenseFilters(year: '2026')).length,
        3,
      );
    });

    test('未知 type → []；非数组 → []；空 filters 全量返回', () {
      expect(
        filterExpenses(expenses, const ExpenseFilters(type: 'fuel')),
        isEmpty,
      );
      expect(filterExpenses(null, const ExpenseFilters()), isEmpty);
      expect(filterExpenses(expenses, const ExpenseFilters()).length, 3);
    });
  });

  group('calcExpenseSummary / calcCombinedSummary / sortTypeBreakdown 汇总', () {
    test('calcExpenseSummary 合计两位小数并跳过非法项，byType 分桶', () {
      // Arrange
      final expenses = <Expense>[
        rawExpense(type: 'parking', amount: 10.005),
        rawExpense(type: 'parking', amount: 5),
        rawExpense(type: 'wash', amount: 30),
        rawExpense(amount: 0),
      ];
      // Act
      final summary = calcExpenseSummary(expenses);
      // Assert
      expect(summary.count, 3);
      expect(summary.totalAmount, 45.01);
      expect(
        summary.byType['parking'],
        const ExpenseTypeBucket(count: 2, totalAmount: 15.01),
      );
      expect(
        summary.byType['wash'],
        const ExpenseTypeBucket(count: 1, totalAmount: 30),
      );
    });

    test('calcCombinedSummary 充电费用归入 charge 分项，合计 = 充电 + 养车', () {
      // Arrange
      final records = <ChargeRecord>[
        rawRecord('r1', 100, 20),
        rawRecord('r2', 50.5, 10),
        rawRecord('r3', 0, 5),
      ];
      final expenses = <Expense>[
        storedExpense(<String, dynamic>{'type': 'insurance', 'amount': 200}),
        storedExpense(<String, dynamic>{'type': 'parking', 'amount': 15.5}),
      ];
      // Act
      final summary = calcCombinedSummary(records, expenses);
      // Assert
      expect(summary.chargeCount, 2);
      expect(summary.chargeTotal, 150.5);
      expect(summary.expenseCount, 2);
      expect(summary.expenseTotal, 215.5);
      expect(summary.total, 366);
      expect(
        summary.byType[chargeTypeKey],
        const ExpenseTypeBucket(count: 2, totalAmount: 150.5),
      );
      expect(
        summary.byType['insurance'],
        const ExpenseTypeBucket(count: 1, totalAmount: 200),
      );
    });

    test('sortTypeBreakdown 降序 + percent 四舍五入', () {
      // Arrange
      const summary = CombinedSummary(
        chargeCount: 5,
        chargeTotal: 150,
        expenseCount: 5,
        expenseTotal: 150,
        total: 300,
        byType: <String, ExpenseTypeBucket>{
          'charge': ExpenseTypeBucket(count: 5, totalAmount: 150),
          'insurance': ExpenseTypeBucket(count: 1, totalAmount: 100),
          'parking': ExpenseTypeBucket(count: 4, totalAmount: 50),
        },
      );
      // Act
      final breakdown = sortTypeBreakdown(summary);
      // Assert
      expect(breakdown.map((item) => item.key).toList(), <String>[
        'charge',
        'insurance',
        'parking',
      ]);
      expect(breakdown[0].key, 'charge');
      expect(breakdown[0].label, 'Charging');
      expect(breakdown[0].percent, 50);
      expect(breakdown[1].percent, 33);
    });

    test('空输入返回空汇总', () {
      expect(
        calcExpenseSummary(null),
        const ExpenseSummary(
          count: 0,
          totalAmount: 0,
          byType: <String, ExpenseTypeBucket>{},
        ),
      );
      expect(calcCombinedSummary(null, null).total, 0);
      expect(sortTypeBreakdown(null), isEmpty);
    });
  });

  group('buildReportTextLine 文字小结', () {
    test('正常文案带金额与占比', () {
      // Arrange
      final breakdown = <TypeBreakdownItem>[
        const TypeBreakdownItem(
          key: 'charge',
          label: 'Charging',
          count: 5,
          totalAmount: 0,
          percent: 42,
        ),
        const TypeBreakdownItem(
          key: 'insurance',
          label: 'Insurance',
          count: 1,
          totalAmount: 0,
          percent: 35,
        ),
        const TypeBreakdownItem(
          key: 'parking',
          label: 'Parking',
          count: 4,
          totalAmount: 0,
          percent: 15,
        ),
      ];
      // Act
      final line = buildReportTextLine(
        breakdown,
        4860,
        periodLabel: 'This year',
      );
      // Assert
      expect(
        line,
        'This year · Total maintenance spend: \$4,860.00; '
        'Charging 42%, Insurance 35%, Parking 15%',
      );
    });

    test('超过 3 项时其余合并为「其他」', () {
      // Arrange
      final breakdown = <TypeBreakdownItem>[
        const TypeBreakdownItem(
          key: 'charge',
          label: 'Charging',
          count: 0,
          totalAmount: 0,
          percent: 50,
        ),
        const TypeBreakdownItem(
          key: 'insurance',
          label: 'Insurance',
          count: 0,
          totalAmount: 0,
          percent: 20,
        ),
        const TypeBreakdownItem(
          key: 'parking',
          label: 'Parking',
          count: 0,
          totalAmount: 0,
          percent: 10,
        ),
        const TypeBreakdownItem(
          key: 'wash',
          label: 'Car Wash',
          count: 0,
          totalAmount: 0,
          percent: 8,
        ),
        const TypeBreakdownItem(
          key: 'maintenance',
          label: 'Maintenance & Repair',
          count: 0,
          totalAmount: 0,
          percent: 5,
        ),
      ];
      // Act
      final line = buildReportTextLine(
        breakdown,
        1000,
        periodLabel: 'Aug 2026',
      );
      // Assert
      expect(
        line,
        'Aug 2026 · Total maintenance spend: \$1,000.00; '
        'Charging 50%, Insurance 20%, Parking 10%, Other 13%',
      );
    });

    test('total 为 0 → 暂无支出文案', () {
      expect(
        buildReportTextLine(
          const <TypeBreakdownItem>[],
          0,
          periodLabel: 'This year',
        ),
        'This year · No expenses yet',
      );
    });
  });

  group('pickTopExpense 最高单笔', () {
    test('返回金额最大项（含类型文案）', () {
      // Arrange
      final expenses = <Expense>[
        storedExpense(<String, dynamic>{'type': 'parking', 'amount': 15}),
        storedExpense(<String, dynamic>{'type': 'insurance', 'amount': 3600}),
        storedExpense(<String, dynamic>{'type': 'wash', 'amount': 30}),
      ];
      // Act
      final top = pickTopExpense(expenses);
      // Assert
      expect(top, const TopExpense(amount: 3600, typeLabel: 'Insurance'));
    });

    test('并列最大取先出现的一项；非法项被跳过', () {
      // Arrange
      final expenses = <Expense>[
        storedExpense(<String, dynamic>{
          'id': 'a',
          'type': 'wash',
          'amount': 50,
        }),
        storedExpense(<String, dynamic>{
          'id': 'b',
          'type': 'parking',
          'amount': 50,
        }),
        rawExpense(amount: -1),
      ];
      // Act
      final top = pickTopExpense(expenses);
      // Assert
      expect(top?.typeLabel, 'Car Wash');
    });

    test('空数组 / 非数组 / 全非法 → null', () {
      expect(pickTopExpense(<Expense>[]), isNull);
      expect(pickTopExpense(null), isNull);
      expect(pickTopExpense(<Expense>[rawExpense(amount: 0)]), isNull);
    });
  });

  group('calcCombinedMonthlyTotals 年度逐月合并', () {
    test('充电 cost 与养车 amount 按月合并，固定 12 项', () {
      // Arrange
      final records = <ChargeRecord>[
        rawRecord('2026-01-10', 100),
        rawRecord('2026-01-20', 50),
        rawRecord('2026-03-05', 30),
        rawRecord('2025-12-31', 999), // 非目标年
      ];
      final expenses = <Expense>[
        storedExpense(<String, dynamic>{'date': '2026-01-15', 'amount': 200}),
        storedExpense(<String, dynamic>{'date': '2026-12-01', 'amount': 40}),
        rawExpense(date: '2026-13-01', amount: 1), // 非法日期（裸对象）
      ];
      // Act
      final months = calcCombinedMonthlyTotals(records, expenses, 2026);
      // Assert
      expect(months.length, 12);
      expect(
        months[0],
        const MonthlyTotal(monthKey: '2026-01', count: 3, totalCost: 350),
      );
      expect(
        months[2],
        const MonthlyTotal(monthKey: '2026-03', count: 1, totalCost: 30),
      );
      expect(
        months[11],
        const MonthlyTotal(monthKey: '2026-12', count: 1, totalCost: 40),
      );
      final sum = months.fold<double>(0, (acc, m) => acc + m.totalCost);
      expect(sum, 420);
    });

    test('空输入返回 12 项全 0，且兼容 calcBarPercents 形状', () {
      // Act
      final months = calcCombinedMonthlyTotals(null, <Expense>[], '2026');
      // Assert
      expect(months.length, 12);
      expect(months.every((m) => m.count == 0 && m.totalCost == 0), isTrue);
      expect(months[0].totalCost, 0);
    });
  });

  group('formatDateCn 中文日期', () {
    test('合法日期 → 英文全格式', () {
      expect(formatDateCn('2026-08-28'), 'Aug 28, 2026');
      expect(formatDateCn('2026-01-01'), 'Jan 1, 2026');
    });

    test('非法日期 → 空串', () {
      expect(formatDateCn('2026/08/28'), '');
      expect(formatDateCn(''), '');
      expect(formatDateCn(null), '');
    });
  });

  group('applyVehicleRename / applyVehicleRemoval 车辆同步', () {
    // Arrange
    final expenses = <Expense>[
      storedExpense(<String, dynamic>{
        'id': 'a',
        'vehicleId': 'v-1',
        'vehicleName': '旧名',
      }),
      storedExpense(<String, dynamic>{
        'id': 'b',
        'vehicleId': 'v-2',
        'vehicleName': '另一台',
      }),
    ];

    test('改名仅刷新关联支出的快照', () {
      // Act
      final next = applyVehicleRename(expenses, 'v-1', '新名');
      // Assert
      expect(next[0].vehicleName, '新名');
      expect(next[1].vehicleName, '另一台');
      expect(expenses[0].vehicleName, '旧名');
    });

    test('删除清除关联支出的车辆字段', () {
      // Act
      final next = applyVehicleRemoval(expenses, 'v-1');
      // Assert
      expect(next[0].vehicleId, isNull);
      expect(next[0].vehicleName, isNull);
      expect(next[1].vehicleId, 'v-2');
    });

    test('非数组 / 缺 vehicleId 返回空或原拷贝', () {
      expect(applyVehicleRename(null, 'v-1', 'x'), isEmpty);
      expect(applyVehicleRemoval(expenses, '').length, 2);
    });
  });

  group('applyVehicleSnapshotRename / Removal 补充守卫（源自 vehicles 测试）', () {
    test('车名 trim + 截断到上限（与表单同口径）', () {
      final items = <Expense>[
        storedExpense(<String, dynamic>{'vehicleId': 'v1', 'vehicleName': '旧'}),
      ];
      final renamed = applyVehicleSnapshotRename(items, 'v1', '  白边  ');
      expect(renamed[0].vehicleName, '白边');
      final truncated = applyVehicleSnapshotRename(items, 'v1', 'x' * 30);
      expect(truncated[0].vehicleName?.length, vehicleNameMaxLength);
    });

    test('null 车名与空守卫（空守卫返回拷贝而非原引用）', () {
      final items = <Expense>[
        storedExpense(<String, dynamic>{
          'vehicleId': 'v1',
          'vehicleName': '旧名',
        }),
      ];
      expect(applyVehicleSnapshotRename(items, 'v1', null)[0].vehicleName, '');
      expect(applyVehicleSnapshotRename(null, 'v1', 'x'), isEmpty);
      final guarded = applyVehicleSnapshotRename(items, '', 'x');
      expect(guarded, items);
      expect(identical(guarded, items), isFalse);
    });

    test('删除快照同步空守卫', () {
      expect(applyVehicleSnapshotRemoval(null, 'v1'), isEmpty);
      expect(applyVehicleSnapshotRemoval(<Expense>[], 'v1'), isEmpty);
    });
  });
}
