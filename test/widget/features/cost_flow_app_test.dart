import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/app.dart';
import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';

void main() {
  testWidgets('full app: costs → add expense → vehicle picker', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.setSurfaceSize(const Size(430, 932));

    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final localStorage = LocalStorage(prefs);
    final kv = SharedPrefsKeyValueStore(prefs);
    await kv.setJson('vehicles', [
      {
        'id': 'v1',
        'name': 'My EV',
        'battery': 82,
        'note': '',
        'photoPath': '',
        'isDefault': true,
        'createdAt': 1,
        'updatedAt': 1,
      },
    ]);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localStorageProvider.overrideWithValue(localStorage),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const EvToolApp()),
    );
    await tester.pumpAndSettle();

    // 切到养车支出 tab
    await tester.tap(find.text('Costs'));
    await tester.pumpAndSettle();

    // 空态 CTA：记一笔支出
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    expect(find.text('Add Expense'), findsOneWidget);

    // 滚动到关联车辆字段并点开弹层
    for (var i = 0; i < 10; i++) {
      if (find.byIcon(Icons.directions_car_rounded).evaluate().isNotEmpty) {
        break;
      }
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byIcon(Icons.directions_car_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Choose vehicle'), findsOneWidget);
    expect(find.text('My EV'), findsWidgets);

    await tester.tap(find.text('No vehicle'));
    await tester.pumpAndSettle();
    expect(find.text('Choose vehicle'), findsNothing);
    expect(find.text('No vehicle'), findsOneWidget);
  });
}
