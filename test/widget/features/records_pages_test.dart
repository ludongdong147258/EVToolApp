import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';
import 'package:ev_tool_app/features/records/presentation/pages/record_add_page.dart';
import 'package:ev_tool_app/features/records/presentation/pages/records_page.dart';

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

  testWidgets('records_page 空态展示添加引导', (tester) async {
    final container = await bootstrap();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RecordsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('充电记录'), findsWidgets);
    expect(find.text('暂无充电记录'), findsOneWidget);
    expect(find.text('添加记录'), findsOneWidget);
  });

  testWidgets('records_page 有记录时展示月度 hero 与最近记录', (tester) async {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RecordsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('快充'), findsOneWidget);
    expect(find.text('家充'), findsOneWidget);
    expect(find.text('最近记录 · 2 条'), findsOneWidget);
    expect(find.byType(RecordAddPage), findsNothing);
  });

  testWidgets('record_add_page 表单默认值与实时度电成本提示', (tester) async {
    final container = await bootstrap();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RecordAddPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('添加充电记录'), findsOneWidget);
    expect(find.text('快充'), findsOneWidget);

    // 输入费用与电量 → 出现度电成本提示
    await tester.enterText(find.byType(TextField).at(0), '30');
    await tester.enterText(find.byType(TextField).at(1), '40');
    await tester.pump();

    expect(find.textContaining('度电成本约 0.75 元/kWh'), findsOneWidget);
  });
}
