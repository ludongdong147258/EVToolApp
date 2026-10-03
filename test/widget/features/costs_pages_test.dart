import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';
import 'package:ev_tool_app/features/costs/presentation/pages/cost_add_page.dart';
import 'package:ev_tool_app/features/costs/presentation/pages/cost_list_page.dart';

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

  testWidgets('cost_list_page 空态展示记录引导', (tester) async {
    final container = await bootstrap();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CostListPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maintenance Costs'), findsWidgets);
    expect(find.text('No expenses yet'), findsOneWidget);
    expect(find.text('Add expense'), findsOneWidget);
  });

  testWidgets('cost_list_page 有支出时展示 hero 汇总与卡片', (tester) async {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final container = await bootstrap(
      store: {
        'maintenanceCosts': [
          {
            'id': 'e1',
            'type': 'parking',
            'date': '$month-15',
            'amount': 20,
            'note': 'Monthly parking fee',
            'vehicleId': null,
            'vehicleName': null,
            'createdAt': 1,
          },
          {
            'id': 'e2',
            'type': 'insurance',
            'date': '$month-10',
            'amount': 3600,
            'note': '',
            'vehicleId': null,
            'vehicleName': null,
            'createdAt': 2,
          },
        ],
      },
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CostListPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This Month · Expenses'), findsOneWidget);
    expect(find.text('Count'), findsOneWidget);
    expect(find.text('Largest · Insurance'), findsOneWidget);
    expect(find.text('Parking'), findsWidgets); // 筛选 chip + 卡片各一处
    expect(find.text('Monthly parking fee'), findsOneWidget);
    expect(find.text('This Month · 2 entries'), findsOneWidget);
    expect(find.text('-\$20.00'), findsOneWidget);
    expect(find.text('-\$3,600.00'), findsOneWidget);
  });

  testWidgets('cost_add_page 金额校验：空金额保存报行内错误', (tester) async {
    final container = await bootstrap();
    // 拉高视口，让 ListView 中的保存按钮进入构建区
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CostAddPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Expense'), findsOneWidget);
    expect(find.text('Maintenance & Repair'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Enter a valid amount'), findsOneWidget);
    expect(find.text('Please check the highlighted fields'), findsOneWidget);
    // 快进 toast 自动关闭，清掉挂起的 2s 定时器
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  });

  testWidgets('cost_add_page 有效金额可保存并返回列表', (tester) async {
    final container = await bootstrap();
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CostAddPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '20.5');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump(); // 保存 + toast 弹出
    await tester.pump(const Duration(milliseconds: 100));

    final kv = container.read(keyValueStoreProvider);
    expect(kv.getJsonList('maintenanceCosts'), isNotEmpty);
    // 快进 toast 自动关闭，清掉挂起的 2s 定时器
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  });
}
