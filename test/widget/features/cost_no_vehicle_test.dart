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

void main() {
  testWidgets('cost add 无车时显示提示 + 去添加；添加后自动预选默认车', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final localStorage = LocalStorage(prefs);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localStorageProvider.overrideWithValue(localStorage),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CostAddPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 无车：提示文案 + 去添加按钮，无选择框
    expect(find.text('在「我的 → 我的车辆」添加后可关联'), findsOneWidget);
    expect(find.text('去添加'), findsOneWidget);

    // 模拟用户在车辆页经 vehiclesProvider 添加了默认车
    await container
        .read(vehiclesProvider.notifier)
        .add(_vehicle('v1', '小海豹', isDefault: true));
    await tester.pumpAndSettle();

    // 表单 watch 到车辆出现：选择框恢复并预选默认车（didChangeDependencies 补预选）
    expect(find.byIcon(Icons.directions_car_rounded), findsOneWidget);
  });
}
