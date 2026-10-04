import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/core/widgets/undo_bar.dart';

Widget _host() {
  return const MaterialApp(home: Scaffold(body: SizedBox.shrink()));
}

void main() {
  testWidgets('undo bar auto-dismisses after duration', (tester) async {
    var undoCount = 0;
    await tester.pumpWidget(_host());

    showUndoBar(
      tester.state<ScaffoldState>(find.byType(Scaffold)).context,
      text: 'Deleted 1 record',
      onUndo: () => undoCount++,
      duration: const Duration(seconds: 5),
    );

    // 进入动画完成
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);

    // 超时 + 出场动画后应自动消失（带 action 的 SnackBar 默认 persist=true 会驻留）
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(undoCount, 0);
  });

  testWidgets('tapping undo triggers callback', (tester) async {
    var undoCount = 0;
    await tester.pumpWidget(_host());

    showUndoBar(
      tester.state<ScaffoldState>(find.byType(Scaffold)).context,
      text: 'Deleted 1 record',
      onUndo: () => undoCount++,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SnackBarAction));
    await tester.pumpAndSettle();
    expect(undoCount, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('second show replaces the previous bar', (tester) async {
    await tester.pumpWidget(_host());
    final context = tester.state<ScaffoldState>(find.byType(Scaffold)).context;

    showUndoBar(context, text: 'first', onUndo: () {});
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);

    showUndoBar(context, text: 'second', onUndo: () {});
    await tester.pumpAndSettle();
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
  });
}
