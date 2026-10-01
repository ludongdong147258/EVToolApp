import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/core/domain/vehicles.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';
import 'package:ev_tool_app/features/costs/presentation/pages/cost_add_page.dart';
import 'package:ev_tool_app/features/records/presentation/providers/records_provider.dart';

Vehicle _vehicle(String id, String name, {bool isDefault = false}) => Vehicle(
  id: id,
  name: name,
  battery: 82,
  note: '',
  photoPath: '',
  isDefault: isDefault,
  createdAt: 1,
  updatedAt: 1,
);

Future<ProviderContainer> _bootstrap() async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      localStorageProvider.overrideWithValue(LocalStorage(prefs)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  testWidgets('无车时仍显示选择框（与添加充电记录一致），弹层仅「暂不关联」', (tester) async {
    final container = await _bootstrap();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CostAddPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 无车：字段始终显示（值「暂不关联」），无提示行/去添加按钮
    expect(find.byIcon(Icons.directions_car_rounded), findsOneWidget);
    expect(find.text('暂不关联'), findsOneWidget);
    expect(find.text('去添加'), findsNothing);

    // 点开弹层：无车时只有「暂不关联」可选
    // （字段本身也显示「暂不关联」，弹层打开后共 2 处）
    await tester.tap(find.byIcon(Icons.directions_car_rounded));
    await tester.pumpAndSettle();
    expect(find.text('选择车辆'), findsOneWidget);
    expect(find.text('暂不关联'), findsWidgets);
  });

  testWidgets('添加车辆后字段自动预选默认车', (tester) async {
    final container = await _bootstrap();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CostAddPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 模拟用户在车辆页经 vehiclesProvider 添加了默认车
    await container
        .read(vehiclesProvider.notifier)
        .add(_vehicle('v1', '小海豹', isDefault: true));
    await tester.pumpAndSettle();

    // 字段值由「暂不关联」切换为默认车名
    expect(find.byIcon(Icons.directions_car_rounded), findsOneWidget);
    expect(find.text('小海豹'), findsOneWidget);
  });
}
