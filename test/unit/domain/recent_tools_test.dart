/// recent_tools.dart 单测（移植自 src/lib/__tests__/recentTools.test.js）
library;

import 'package:ev_tool_app/core/domain/recent_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pushRecentTool 最近使用列表', () {
    test('新使用项置顶并去重', () {
      // Act
      final next = pushRecentTool(<String>['a', 'b'], 'b');

      // Assert
      expect(next, <String>['b', 'a']);
    });

    test('超出上限截断（默认 3 个）', () {
      // Act
      final next = pushRecentTool(<String>['a', 'b', 'c'], 'd');

      // Assert
      expect(next, <String>['d', 'a', 'b']);
      expect(next.length, recentToolsLimit);
    });

    test('非法输入不抛错且不改有效部分', () {
      expect(pushRecentTool(null, 'a'), <String>['a']);
      expect(pushRecentTool(<String>['a', 'b'], ''), <String>['a', 'b']);
      // JS 测试中的 [a, 3, null] 在 Dart 强类型下对应含空串脏值，
      // 空串与 null 一样被过滤
      expect(pushRecentTool(<String>['a', '', ''], 'b'), <String>['b', 'a']);
    });

    test('limit 可注入且非法 limit 不截断', () {
      expect(pushRecentTool(<String>['a', 'b'], 'c', 5).length, 3);
      expect(pushRecentTool(<String>['a', 'b'], 'c', 0), <String>['a', 'b']);
    });
  });
}
