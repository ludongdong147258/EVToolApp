import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/core/storage/local_storage.dart';
import 'package:ev_tool_app/features/pro/data/pro_repository.dart';
import 'package:ev_tool_app/features/pro/presentation/paywall_sheet.dart';

/// paywall 弹层各形态冒烟（无 key 环境：sdkAvailable 恒 false，不触平台通道）。
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

  /// 宿主页放一个按钮触发 showPaywallSheet（返回值此处不消费）。
  Future<void> pumpHost(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showPaywallSheet(TestContext.of(tester)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('paywall_sheet（无 key 环境）', () {
    testWidgets('已是 Pro（无 key 默认解锁）显示 Pro is active', (tester) async {
      final container = await bootstrap();

      await pumpHost(tester, container);

      expect(find.text('Pro is active'), findsOneWidget);
      expect(find.text('Thanks for supporting VoltLedger!'), findsOneWidget);
    });

    testWidgets('非 Pro 且无 key 显示 dev 占位', (tester) async {
      final container = await bootstrap();
      container.read(proStatusProvider.notifier).applyFromRevenueCat(false);

      await pumpHost(tester, container);

      expect(find.text('Pro features unlocked'), findsOneWidget);
      expect(
        find.text('Development build — no store connection.'),
        findsOneWidget,
      );
      // dev 模式不渲染购买入口
      expect(find.text('Restore Purchases'), findsNothing);
    });

    // 注：重试占位分支（"Plans are unavailable. Tap to retry."）仅在
    // sdkAvailable 且 offerings 拉取失败/为空时可达，单测无 SDK 无法触达，
    // 依赖模拟器弱网手测。

    testWidgets('弹层期间 Pro 激活 → 自动关闭（误拦修复回归）', (tester) async {
      final container = await bootstrap();
      container.read(proStatusProvider.notifier).applyFromRevenueCat(false);

      await pumpHost(tester, container);
      expect(
        find.text('Development build — no store connection.'),
        findsOneWidget,
      );

      // 模拟弹层打开期间 entitlement 激活（Restore/后台刷新）
      container.read(proStatusProvider.notifier).applyFromRevenueCat(true);
      await tester.pumpAndSettle();

      // 弹层已自动关闭，内容不再可见
      expect(
        find.text('Development build — no store connection.'),
        findsNothing,
      );
    });
  });
}

/// 从 tester 取宿主 BuildContext（触发 showModalBottomSheet 需要）。
class TestContext {
  static BuildContext of(WidgetTester tester) =>
      tester.element(find.byType(Scaffold));
}
