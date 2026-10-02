import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/core/widgets/app_toast.dart';

void main() {
  testWidgets('普通场景：toast 立即显示', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _ToastHostPage()));
    await tester.tap(find.text('show'));
    await tester.pump();

    expect(find.text('已保存'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('已保存'), findsNothing);
  });

  testWidgets('golden：大字号下 toast 无异常条纹（缺 Material 祖先后果守护）', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // 模拟用户开了大字号（辅助功能文本缩放）
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(
      tester.platformDispatcher.clearTextScaleFactorTestValue,
    );

    await tester.pumpWidget(const MaterialApp(home: _ToastHostPage()));
    await tester.tap(find.text('show'));
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens_tmp/toast_scale.png'),
    );
    // 消化 toast 的 2 秒移除 Timer
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('路由退出转场中调用：等转场结束再插入 toast', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _ToastHostPage()));

    // 打开底部弹层
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    expect(find.text('sheet'), findsOneWidget);

    // pop 后立刻 toast（复现保存成功场景）
    await tester.tap(find.text('pop+toast'));
    await tester.pump(const Duration(milliseconds: 100));

    // 转场进行中：toast 尚未插入
    expect(find.text('sheet'), findsOneWidget);
    expect(find.text('已保存'), findsNothing);

    // 转场结束后：toast 出现
    await tester.pumpAndSettle();
    expect(find.text('sheet'), findsNothing);
    expect(find.text('已保存'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('已保存'), findsNothing);
  });
}

/// 承载 toast 调用的最小页面：按钮触发；弹层按钮复现 pop+toast 时序。
class _ToastHostPage extends StatelessWidget {
  const _ToastHostPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextButton(
            onPressed: () => showAppToast(context, '已保存'),
            child: const Text('show'),
          ),
          TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (sheetContext) => Scaffold(
                body: Center(
                  child: Column(
                    children: [
                      const Text('sheet'),
                      TextButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          showAppToast(sheetContext, '已保存');
                        },
                        child: const Text('pop+toast'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: const Text('open sheet'),
          ),
        ],
      ),
    );
  }
}
