import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/core/widgets/app_toast.dart';

void main() {
  testWidgets('probe: toast overflow details at large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppToast(context, 'Saved'),
              child: const Text('show'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pump();

    debugDumpApp();
    debugPrint('toast text rect: ${tester.getRect(find.text('Saved'))}');
    await tester.pump(const Duration(seconds: 3));
  });
}
