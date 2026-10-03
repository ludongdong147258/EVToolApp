/// date_utils.dart 单测（移植自 src/lib/__tests__/dateUtils.test.js）
library;

import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dateUtils pad2', () {
    test('个位数补零', () {
      expect(pad2(0), '00');
      expect(pad2(5), '05');
    });

    test('两位及以上不补零', () {
      expect(pad2(10), '10');
      expect(pad2(123), '123');
    });
  });

  group('dateUtils isValidDateString', () {
    test('合法日期返回 true', () {
      expect(isValidDateString('2025-08-01'), isTrue);
      expect(isValidDateString('2024-02-29'), isTrue); // 闰年
    });

    test('格式非法返回 false', () {
      expect(isValidDateString('2025/08/01'), isFalse);
      expect(isValidDateString('2025-8-1'), isFalse);
      expect(isValidDateString('20250801'), isFalse);
      expect(isValidDateString(''), isFalse);
    });

    test('历法非法返回 false', () {
      expect(isValidDateString('2025-13-01'), isFalse);
      expect(isValidDateString('2025-00-10'), isFalse);
    });

    test('日越界会引擎滚动为下月（历史口径，防顺手修复改变行为）', () {
      // new Date("2025-02-30") 不产生 NaN 而是滚动为 3 月 2 日 → 判定合法
      // （仅日 ≤ 31 时滚动；02-29 平年、04-31 同理）。
      // 与表单 normalize 的历史行为一致，此处钉住口径。
      expect(isValidDateString('2025-02-30'), isTrue);
      expect(isValidDateString('2025-04-31'), isTrue);
      expect(isValidDateString('2023-02-29'), isTrue); // 平年 2 月 29 滚动
      expect(isValidDateString('2025-08-32'), isFalse); // 日 > 31 语法非法
    });

    test('非字符串返回 false', () {
      expect(isValidDateString(null), isFalse);
      expect(isValidDateString(20250801), isFalse);
    });
  });

  group('dateUtils getTodayStr', () {
    test('注入 now 输出 YYYY-MM-DD', () {
      // JS new Date(2025, 7, 1) 的月份为 0 基 → Dart 1 基为 8 月
      expect(getTodayStr(now: DateTime(2025, 8, 1)), '2025-08-01');
      expect(getTodayStr(now: DateTime(2024, 1, 31)), '2024-01-31');
    });
  });

  group('dateUtils getMonthKey', () {
    test('日期字符串 → YYYY-MM', () {
      expect(getMonthKey('2025-08-01'), '2025-08');
    });

    test('格式非法返回 null', () {
      expect(getMonthKey('2025/08/01'), isNull);
      expect(getMonthKey('2025-08'), isNull);
      expect(getMonthKey(null), isNull);
    });
  });

  group('dateUtils getCurrentMonthKey', () {
    test('注入 now 输出 YYYY-MM', () {
      expect(getCurrentMonthKey(now: DateTime(2025, 8, 15)), '2025-08');
      expect(getCurrentMonthKey(now: DateTime(2024, 12, 1)), '2024-12');
    });
  });

  group('dateUtils formatTimestampDate', () {
    test('合法时间戳 → YYYY-MM-DD', () {
      expect(
        formatTimestampDate(
          DateTime(2025, 8, 1, 10, 30).millisecondsSinceEpoch,
        ),
        '2025-08-01',
      );
    });

    test('数字字符串输入同样有效', () {
      final ts = DateTime(2024, 1, 31, 23, 59).millisecondsSinceEpoch;
      expect(formatTimestampDate(ts.toString()), '2024-01-31');
    });

    test('非法输入返回空串', () {
      expect(formatTimestampDate(0), '');
      expect(formatTimestampDate(-1), '');
      expect(formatTimestampDate('abc'), '');
      expect(formatTimestampDate(null), '');
    });
  });

  group('dateUtils 格式正则常量', () {
    test('DATE_RE 匹配 YYYY-MM-DD', () {
      expect(dateRe.hasMatch('2025-08-01'), isTrue);
      expect(dateRe.hasMatch('2025-8-1'), isFalse);
    });

    test('MONTH_KEY_RE 匹配 YYYY-MM', () {
      expect(monthKeyRe.hasMatch('2025-08'), isTrue);
      expect(monthKeyRe.hasMatch('2025-08-01'), isFalse);
    });
  });

  group('英文日期格式化 helper', () {
    test('formatMonthDay → "Aug 28"', () {
      expect(formatMonthDay('2026-08-28'), 'Aug 28');
      expect(formatMonthDay('2026-01-01'), 'Jan 1');
      expect(formatMonthDay('bad'), '');
      expect(formatMonthDay(null), '');
    });

    test('formatFullDate → "Aug 28, 2026"', () {
      expect(formatFullDate('2026-08-28'), 'Aug 28, 2026');
      expect(formatFullDate(''), '');
    });

    test('formatMonthLabel → "Aug 2026"', () {
      expect(formatMonthLabel('2026-08'), 'Aug 2026');
      expect(formatMonthLabel('2026-12'), 'Dec 2026');
      expect(formatMonthLabel('whatever'), '');
      expect(formatMonthLabel(null), '');
    });
  });
}
