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

  testWidgets('tools_page 渲染分组与全部工具入口', (tester) async {
    final container = await bootstrap();

    await pumpPage(
      tester,
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ToolsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('实用工具'), findsOneWidget);
    expect(find.text('省钱计算'), findsOneWidget);
    expect(find.text('地图服务'), findsOneWidget);
    expect(find.text('装备导购'), findsOneWidget);
    expect(find.text('备忘与手册'), findsOneWidget);
    expect(find.text('续航静态估算'), findsOneWidget);
    expect(find.text('油电成本对比'), findsOneWidget);
    expect(find.text('峰谷电价优化'), findsOneWidget);
    expect(find.text('私桩安装测算'), findsOneWidget);
    expect(find.text('附近充电站'), findsOneWidget);
    expect(find.text('充电装备'), findsOneWidget);
    expect(find.text('年检维保备忘录'), findsOneWidget);
    expect(find.text('改装合规自查'), findsOneWidget);
    expect(find.text('三电质保手册'), findsOneWidget);
    // 无使用记录时不渲染最近使用组
    expect(find.text('最近使用'), findsNothing);
  });

  testWidgets('tools_page 有使用记录时置顶最近使用组', (tester) async {
    final container = await bootstrap(
      store: {
        'toolsRecentUse': ['fuel-vs-ev', 'home-charger'],
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

    expect(find.text('最近使用'), findsOneWidget);
    // 最近使用组 + 省钱计算组各渲染一次
    expect(find.text('油电成本对比'), findsNWidgets(2));
    expect(find.text('私桩安装测算'), findsNWidgets(2));
  });

  testWidgets('fuel_ev_calc_page 默认输入直接展示结果', (tester) async {
    final container = await bootstrap();

    await pumpPage(
      tester,
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: FuelEvCalcPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('年度成本对比'), findsOneWidget);
    // 默认 15000 km · 8.5L/8 元 → 燃油 ¥10,200；15kWh/1.2 元 → 电动 ¥2,700
    expect(find.text('¥ 10,200'), findsOneWidget);
    expect(find.text('¥ 2,700'), findsOneWidget);
    expect(find.text('年度节省'), findsOneWidget);
    expect(find.textContaining('每万公里节省 ¥ 5,000'), findsOneWidget);

    // 改电价为非法输入：保留旧结果 + 红框提示
    await tester.enterText(find.byType(TextField).at(3), '0');
    await tester.pump();
    expect(find.text('¥ 10,200'), findsOneWidget);
  });

  testWidgets('home_charger_calc_page 向导三步推进并计算总额', (tester) async {
    final container = await bootstrap();

    await pumpPage(
      tester,
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeChargerCalcPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 第 1 步：默认 7kW + 30m 线缆 → 基础包 ¥2,850
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('安装详情'), findsOneWidget);
    expect(find.text('¥ 2,850'), findsOneWidget);

    await tester.ensureVisible(find.text('下一步'));
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 第 2 步：默认地下车库（+200）+ 保护箱（+230）
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('环境条件'), findsOneWidget);
    expect(find.text('地下车库'), findsOneWidget);
    expect(find.text('需安装保护箱'), findsOneWidget);
    expect(find.text('¥ 430'), findsOneWidget);

    await tester.ensureVisible(find.text('下一步'));
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 第 3 步：总额 = 2850 + 430 = ¥3,280
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('费用明细'), findsOneWidget);
    expect(find.text('¥ 3,280'), findsOneWidget);
    expect(find.text('保存预估结果'), findsOneWidget);
    expect(find.text('查看所需文件'), findsOneWidget);
  });
}
