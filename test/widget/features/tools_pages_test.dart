import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';
import 'package:ev_tool_app/features/tools/presentation/pages/fuel_ev_calc_page.dart';
import 'package:ev_tool_app/features/tools/presentation/pages/home_charger_calc_page.dart';
import 'package:ev_tool_app/features/tools/presentation/pages/tools_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /* 拉高测试视口，让 ListView 一次性构建全部内容（避免懒加载截断断言） */
  Future<void> pumpPage(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(child);
  }

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

  testWidgets('tools_page renders groups and all tool entries', (tester) async {
    final container = await bootstrap();

    await pumpPage(
      tester,
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ToolsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Savings Calculators'), findsOneWidget);
    expect(find.text('Maps'), findsOneWidget);
    expect(find.text('Range Estimate'), findsOneWidget);
    expect(find.text('Fuel vs EV Cost'), findsOneWidget);
    expect(find.text('Time-of-Use Savings'), findsOneWidget);
    expect(find.text('Nearby Stations'), findsOneWidget);
    // 无使用记录时不渲染最近使用组
    expect(find.text('Recently used'), findsNothing);
  });

  testWidgets('tools_page pins recently used group when history exists', (
    tester,
  ) async {
    final container = await bootstrap(
      store: {
        'toolsRecentUse': ['fuel-vs-ev', 'range-estimate'],
      },
    );

    await pumpPage(
      tester,
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ToolsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recently used'), findsOneWidget);
    // 最近使用组 + 省钱计算组各渲染一次
    expect(find.text('Fuel vs EV Cost'), findsNWidgets(2));
    expect(find.text('Range Estimate'), findsNWidgets(2));
  });

  testWidgets('fuel_ev_calc_page shows results for default inputs', (
    tester,
  ) async {
    final container = await bootstrap();

    await pumpPage(
      tester,
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: FuelEvCalcPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Annual cost comparison'), findsOneWidget);
    // 默认 13,500 mi · 28 MPG / $3.30 → 燃油 $1,591；3.3 mi/kWh / $0.16 → 电动 $655
    expect(find.text('\$1,591.00'), findsOneWidget);
    expect(find.text('\$655.00'), findsOneWidget);
    expect(find.text('Annual savings'), findsOneWidget);
    expect(
      find.textContaining('Saves \$693.00 per 10,000 miles'),
      findsOneWidget,
    );

    // 改电价为非法输入：保留旧结果 + 红框提示
    await tester.enterText(find.byType(TextField).at(3), '0');
    await tester.pump();
    expect(find.text('\$1,591.00'), findsOneWidget);
  });

  testWidgets(
    'home_charger_calc_page advances three steps and computes total',
    (tester) async {
      final container = await bootstrap();

      await pumpPage(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomeChargerCalcPage()),
        ),
      );
      await tester.pumpAndSettle();

      // 第 1 步：默认 7kW + 30m 线缆 → 基础包 \$2,850
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('Installation'), findsOneWidget);
      expect(find.text('\$2,850.00'), findsOneWidget);

      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // 第 2 步：默认地下车库（+200）+ 保护箱（+230）
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Site conditions'), findsOneWidget);
      expect(find.text('Underground garage'), findsOneWidget);
      expect(find.text('Install protection box'), findsOneWidget);
      expect(find.text('\$430.00'), findsOneWidget);

      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // 第 3 步：总额 = 2850 + 430 = \$3,280
      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.text('Cost breakdown'), findsOneWidget);
      expect(find.text('\$3,280.00'), findsOneWidget);
      expect(find.text('Save estimate'), findsOneWidget);
      expect(find.text('Required documents'), findsOneWidget);
    },
  );
}
