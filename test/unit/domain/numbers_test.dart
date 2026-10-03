/// numbers.dart 单测（移植自 src/lib/__tests__/numbers.test.js）
library;

import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toNumber', () {
    test('数字原样返回', () {
      expect(toNumber(3.5), 3.5);
      expect(toNumber(0), 0);
    });

    test('数字字符串转数字', () {
      expect(toNumber('3.5'), 3.5);
      expect(toNumber(' 12 '), 12);
    });

    test('非法输入返回 null（JS NaN）', () {
      expect(toNumber('abc'), isNull);
      expect(toNumber(null), isNull);
      expect(toNumber(''), isNull);
    });
  });

  group('toYuan', () {
    test('分安全取整到两位小数', () {
      expect(toYuan(0.1 + 0.2), 0.3);
      expect(toYuan(345.567), 345.57);
      expect(toYuan(10), 10);
    });
  });

  group('formatYuan', () {
    test('两位小数 + 千分位', () {
      expect(formatYuan(345.5), '345.50');
      expect(formatYuan(1234567.891), '1,234,567.89');
    });

    test('非法输入返回 0.00', () {
      expect(formatYuan('x'), '0.00');
      expect(formatYuan(null), '0.00');
    });
  });

  group('formatAmount', () {
    test('整数千分位', () {
      expect(formatAmount(2850), '2,850');
      expect(formatAmount(1234567), '1,234,567');
    });

    test('四舍五入到整数', () {
      expect(formatAmount(2849.6), '2,850');
    });
  });

  group('formatPrice', () {
    test('分转元，整数省略小数', () {
      expect(formatPrice(1299), '12.99');
      expect(formatPrice(1200), '12');
      expect(formatPrice(50), '0.50');
      expect(formatPrice(0), '0');
    });

    test('非法与负值兜底为 0', () {
      expect(formatPrice(-100), '0');
      expect(formatPrice('abc'), '0');
      expect(formatPrice(null), '0');
    });
  });

  group('generateId', () {
    test('以传入时间戳为前缀', () {
      expect(
        generateId(nowMs: 1755916800000).startsWith('1755916800000-'),
        isTrue,
      );
    });

    test('多次生成不重复', () {
      final ids = <String>{for (var i = 0; i < 50; i++) generateId(nowMs: 1)};
      expect(ids.length, 50);
    });
  });

  group('isValidPositiveNumber', () {
    test('正数（数字与输入框字符串）返回 true', () {
      expect(isValidPositiveNumber(1), isTrue);
      expect(isValidPositiveNumber(0.5), isTrue);
      expect(isValidPositiveNumber('12.5'), isTrue);
    });

    test('0/负数/NaN/空白串返回 false', () {
      expect(isValidPositiveNumber(0), isFalse);
      expect(isValidPositiveNumber(-1), isFalse);
      expect(isValidPositiveNumber('-3'), isFalse);
      expect(isValidPositiveNumber(double.nan), isFalse);
      expect(isValidPositiveNumber(''), isFalse);
      expect(isValidPositiveNumber('  '), isFalse);
      expect(isValidPositiveNumber('abc'), isFalse);
      expect(isValidPositiveNumber(null), isFalse);
    });

    test('带上限：超限 false，等于上限 true', () {
      expect(isValidPositiveNumber(100, max: 100), isTrue);
      expect(isValidPositiveNumber(100.5, max: 100), isFalse);
      expect(isValidPositiveNumber('150', max: 100), isFalse);
    });

    test('缺省上限不设卡', () {
      expect(isValidPositiveNumber(1e12), isTrue);
    });

    test('Infinity 返回 false（toNumber 归一为 NaN）', () {
      expect(isValidPositiveNumber(double.infinity), isFalse);
      expect(isValidPositiveNumber('1e400'), isFalse);
    });

    test('尾随垃圾字符的宽松口径（parseFloat 截断，输入框场景历史行为）', () {
      expect(isValidPositiveNumber('12abc'), isTrue);
    });
  });

  group('formatMoney', () {
    test('加 \$ 前缀并保持两位小数与千分位', () {
      expect(formatMoney(345.5), '\$345.50');
      expect(formatMoney(1234567.891), '\$1,234,567.89');
    });

    test('非法输入返回 \$0.00', () {
      expect(formatMoney(null), '\$0.00');
      expect(formatMoney('abc'), '\$0.00');
    });
  });
}
