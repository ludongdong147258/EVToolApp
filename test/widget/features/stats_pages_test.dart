import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';
import 'package:ev_tool_app/core/theme/app_theme.dart';
import 'package:ev_tool_app/core/widgets/month_bar_chart.dart';
import 'package:ev_tool_app/core/domain/poster.dart';
import 'package:ev_tool_app/core/domain/theme_colors.dart';
import 'package:ev_tool_app/features/costs/presentation/pages/cost_report_page.dart';
import 'package:ev_tool_app/features/stats/presentation/pages/annual_report_page.dart';
import 'package:ev_tool_app/features/stats/presentation/pages/charge_stats_page.dart';
import 'package:ev_tool_app/features/stats/presentation/widgets/annual_poster.dart';

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

      expect(find.text('Charging Stats'), findsWidgets);
      expect(find.text('No charging data yet'), findsOneWidget);
      expect(find.text('Add Now'), findsOneWidget);
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
      expect(find.text('Total Charging Spend'), findsOneWidget);
      expect(find.textContaining('40.00', findRichText: true), findsWidgets);
      // 月份导航标题带「本月」标记
      expect(find.textContaining('This month'), findsOneWidget);
      // 筛选 chips + 年度报告入口 + 导出入口
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Annual Charging Report'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      // 月份列表标题
      expect(find.textContaining('2 records'), findsOneWidget);
    });
  });

  group('annual_report_page', () {
    testWidgets('空态展示去添加引导', (tester) async {
      final container = await bootstrap();

      await pumpPage(tester, container, const AnnualReportPage());

      expect(find.text('Annual Charging Report'), findsWidgets);
      expect(find.text('No charging data yet'), findsOneWidget);
      expect(find.text('Add Records'), findsOneWidget);
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
      expect(find.text('${now.year}'), findsOneWidget);
      // hero 标题 + 12 柱月度费用图
      expect(find.text('${now.year} Annual Charging Spend'), findsOneWidget);
      expect(find.byType(MonthBarChart), findsOneWidget);
      // 充电方式占比 + 年度之最 + 海报入口
      expect(find.text('Charging Mix'), findsOneWidget);
      expect(find.text('Year Highlights'), findsOneWidget);
      expect(find.text('Create Share Poster'), findsOneWidget);
    });
  });

  group('cost_report_page', () {
    testWidgets('两类账单均无数据时整页空态', (tester) async {
      final container = await bootstrap();

      await pumpPage(tester, container, const CostReportPage());

      expect(find.text('Cost Report'), findsWidgets);
      expect(find.text('No data yet'), findsOneWidget);
      expect(find.text('Add a record'), findsOneWidget);
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
      expect(find.textContaining('Total spend'), findsOneWidget);
      expect(find.textContaining('50.00', findRichText: true), findsWidgets);
      // 模式 chips + 月份导航
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.textContaining('This month'), findsOneWidget);
      // 分项图例：充电 + 停车费（金额降序，充电 30 在前）
      expect(find.text('Breakdown'), findsOneWidget);
      expect(find.text('Charging'), findsWidgets);
      expect(find.text('Parking'), findsOneWidget);
      // 小结复制入口
      expect(find.text('Copy'), findsOneWidget);
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
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();

      expect(find.text('Monthly trend'), findsOneWidget);
      expect(find.byType(MonthBarChart), findsOneWidget);
      expect(find.textContaining('This year'), findsOneWidget);
    });
  });

  group('annual_poster 海报色随 accent', () {
    testWidgets('非默认 accent 下快充分割条使用该 accent 主色', (tester) async {
      // Arrange：直接构造最小 PosterModel（快充 100%）
      const model = PosterModel(
        titleText: '2025 Annual Charging Report',
        heroCostText: '\$660.00',
        statLines: [PosterStatLine(label: 'Charges', value: '12', unit: '')],
        barItems: [PosterBar(value: 10, hasRecords: true)],
        fastPercent: 100,
        homePercent: 0,
        bestItems: [],
        sloganText: 'Rookie Owner · A year in EV life',
        footerText: 'VoltLedger · EV Charging Log',
      );
      final blueAccent = getAccentById('blue');

      // Act：蓝色 accent 的浅色主题下渲染海报
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(blueAccent),
          home: const AnnualPoster(model: model),
        ),
      );

      // Assert：分割条为蓝色主色，而非默认绿色
      final coloredBoxes = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .toList();
      expect(
        coloredBoxes.any((b) => b.color == Color(blueAccent.primary)),
        isTrue,
      );
      const defaultGreen = Color(0xFF10B981);
      expect(coloredBoxes.any((b) => b.color == defaultGreen), isFalse);
    });
  });
}
