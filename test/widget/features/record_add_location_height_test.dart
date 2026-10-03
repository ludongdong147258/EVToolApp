import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/core/routing/route_names.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';
import 'package:ev_tool_app/features/maps/presentation/pages/location_picker_page.dart';
import 'package:ev_tool_app/features/records/presentation/pages/record_add_page.dart';

/// 回归测试：充电地点字段在「占位态」与「选点回填态」高度必须一致。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> bootstrap() async {
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

  /// 选点页替身：build 后立刻带结果 pop，模拟用户选点返回。
  Widget fakePicker(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pop(
        const PickedLocation(
          latitude: 22.5,
          longitude: 113.9,
          province: '广东省',
          city: '深圳市',
          locationName: '深圳市南山区科技园南路某某号国家电网充电站附近路口',
        ),
      );
    });
    return const SizedBox.shrink();
  }

  testWidgets('充电地点字段回填前后高度一致', (tester) async {
    final container = await bootstrap();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const RecordAddPage()),
        GoRoute(
          path: RouteNames.locationPicker,
          builder: (context, state) => fakePicker(context),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    double fieldHeight(Finder textFinder) {
      final field = find
          .ancestor(of: textFinder, matching: find.byType(InkWell))
          .first;
      return tester.renderObject<RenderBox>(field).size.height;
    }

    // 滚动到充电地点字段可见
    await tester.ensureVisible(find.text('Choose on map'));
    await tester.pumpAndSettle();
    final placeholderHeight = fieldHeight(find.text('Choose on map'));

    await tester.tap(find.text('Choose on map'));
    await tester.pumpAndSettle();

    final filledFinder = find.textContaining('深圳市 · 深圳市南山区');
    expect(filledFinder, findsOneWidget);
    final filledHeight = fieldHeight(filledFinder);

    expect(filledHeight, placeholderHeight);
  });
}
