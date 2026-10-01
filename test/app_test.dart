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

    // Assert — 4 nav items visible on the records shell
    expect(find.text('充电记录'), findsWidgets);
    expect(find.text('养车支出'), findsOneWidget);
    expect(find.text('实用工具'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
