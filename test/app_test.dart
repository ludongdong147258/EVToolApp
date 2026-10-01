import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/app.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots and renders the 4-tab bottom navigation', (
    tester,
  ) async {
    // Arrange
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final localStorage = LocalStorage(prefs);

    // Act
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localStorageProvider.overrideWithValue(localStorage),
        ],
        child: const EvToolApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Assert — 4 nav items visible on the home shell
    // （"首页" 同时出现在页面标题和导航标签中，故用 findsWidgets）
    expect(find.text('首页'), findsWidgets);
    expect(find.text('充电'), findsOneWidget);
    expect(find.text('工具'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
