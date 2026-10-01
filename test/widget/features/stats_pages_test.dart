import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';
import 'package:ev_tool_app/core/widgets/month_bar_chart.dart';
import 'package:ev_tool_app/features/costs/presentation/pages/cost_report_page.dart';
import 'package:ev_tool_app/features/stats/presentation/pages/annual_report_page.dart';
import 'package:ev_tool_app/features/stats/presentation/pages/charge_stats_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> bootstrap({
    Map<String, Object> store = const {},
  }) async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final localStorage = LocalStorage(prefs);
    final kv = SharedPrefsKeyValueStore(prefs);
    for (final entry in store.entries) {
      await kv.setJson(entry.key, entry.value);
    }
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localStorageProvider.overrideWithValue(localStorage),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  String monthKey(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}';

  Future<void> pumpPage(
    WidgetTester tester,
    ProviderContainer container,
    Widget page,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('charge_stats_page', () {
    testWidgets('空态展示去添加引导', (tester) async {
      final container = await bootstrap();

      await pumpPage(tester, container, const ChargeStatsPage());

      expect(find.text('充电统计'), findsWidgets);
      expect(find.text('暂无充电数据'), findsOneWidget);
      expect(find.text('去添加记录'), findsOneWidget);
    });

    testWidgets('有记录时展示累计 hero 与月份导航', (tester) async {
      final now = DateTime.now();
      final month = monthKey(now);
      final container = await bootstrap(
        store: {
          'chargeRecords': [
            {
              'id': 'r1',
              'type': 'fast',
              'date': '$month-15',
              'cost': 30,
              'energy': 40,
              'createdAt': 1,
            },
            {
              'id': 'r2',
              'type': 'home',
              'date': '$month-10',
              'cost': 10,
              'energy': 15,
              'createdAt': 2,
            },
          ],
        },
      );

      await pumpPage(tester, container, const ChargeStatsPage());

      // 累计 hero（40 + 10 = 40.00 元）
      expect(find.text('累计充电支出'), findsOneWidget);
      expect(find.textContaining('40.00', findRichText: true), findsWidgets);
      // 月份导航标题带「本月」标记
      expect(find.textContaining('本月'), findsOneWidget);
      // 筛选 chips + 年度报告入口 + 导出入口
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('充电年度报告'), findsOneWidget);
      expect(find.text('导出'), findsOneWidget);
      // 月份列表标题
      expect(find.textContaining('2 条'), findsOneWidget);
    });
  });

  group('annual_report_page', () {
    testWidgets('空态展示去添加引导', (tester) async {
      final container = await bootstrap();

      await pumpPage(tester, container, const AnnualReportPage());

      expect(find.text('充电年度报告'), findsWidgets);
      expect(find.text('暂无充电数据'), findsOneWidget);
      expect(find.text('去添加记录'), findsOneWidget);
    });

    testWidgets('有记录时展示年份 chips + 12 柱图 + 占比与年度之最', (tester) async {
      final now = DateTime.now();
      final month = monthKey(now);
      final container = await bootstrap(
        store: {
          'chargeRecords': [
            {
              'id': 'r1',
              'type': 'fast',
              'date': '$month-15',
              'cost': 30,
              'energy': 40,
              'createdAt': 1,
            },
            {
              'id': 'r2',
              'type': 'home',
              'date': '$month-10',
              'cost': 10,
              'energy': 15,
              'createdAt': 2,
            },
          ],
        },
      );

      await pumpPage(tester, container, const AnnualReportPage());

      // 年份 chip（仅有记录的年份）
      expect(find.text('${now.year}年'), findsOneWidget);
      // hero 标题 + 12 柱月度费用图
      expect(find.text('${now.year} 年度充电支出'), findsOneWidget);
      expect(find.byType(MonthBarChart), findsOneWidget);
      // 充电方式占比 + 年度之最 + 海报入口
      expect(find.text('充电方式占比'), findsOneWidget);
      expect(find.text('年度之最'), findsOneWidget);
      expect(find.text('生成分享海报'), findsOneWidget);
    });
  });

  group('cost_report_page', () {
    testWidgets('两类账单均无数据时整页空态', (tester) async {
      final container = await bootstrap();

      await pumpPage(tester, container, const CostReportPage());

      expect(find.text('综合费用统计'), findsWidgets);
      expect(find.text('暂无账单数据'), findsOneWidget);
      expect(find.text('去记一笔'), findsOneWidget);
    });

    testWidgets('有账单时展示周期 hero 与分项占比图例', (tester) async {
      final now = DateTime.now();
      final month = monthKey(now);
      final container = await bootstrap(
        store: {
          'chargeRecords': [
            {
              'id': 'r1',
              'type': 'fast',
              'date': '$month-15',
              'cost': 30,
              'energy': 40,
              'createdAt': 1,
            },
          ],
          'maintenanceCosts': [
            {
              'id': 'e1',
              'type': 'parking',
              'date': '$month-16',
              'amount': 20,
              'note': '小区月停车费',
              'vehicleId': null,
              'vehicleName': null,
              'createdAt': 2,
            },
          ],
        },
      );

      await pumpPage(tester, container, const CostReportPage());

      // 周期 hero
      expect(find.textContaining('用车总花费'), findsOneWidget);
      expect(find.textContaining('50.00', findRichText: true), findsWidgets);
      // 模式 chips + 月份导航
      expect(find.text('月度'), findsOneWidget);
      expect(find.text('年度'), findsOneWidget);
      expect(find.textContaining('本月'), findsOneWidget);
      // 分项图例：充电 + 停车费（金额降序，充电 30 在前）
      expect(find.text('分项占比'), findsOneWidget);
      expect(find.text('充电'), findsWidgets);
      expect(find.text('停车费'), findsOneWidget);
      // 小结复制入口
      expect(find.text('复制'), findsOneWidget);
    });

    testWidgets('年度模式展示 12 柱月度趋势', (tester) async {
      final now = DateTime.now();
      final month = monthKey(now);
      final container = await bootstrap(
        store: {
          'chargeRecords': [
            {
              'id': 'r1',
              'type': 'fast',
              'date': '$month-15',
              'cost': 30,
              'energy': 40,
              'createdAt': 1,
            },
          ],
        },
      );

      await pumpPage(tester, container, const CostReportPage());
      await tester.tap(find.text('年度'));
      await tester.pumpAndSettle();

      expect(find.text('月度趋势'), findsOneWidget);
      expect(find.byType(MonthBarChart), findsOneWidget);
      expect(find.textContaining('今年'), findsOneWidget);
    });
  });
}
