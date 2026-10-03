/// user_badges.dart 单测（移植自 src/lib/__tests__/userBadges.test.js）
library;

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/user_badges.dart';
import 'package:flutter_test/flutter_test.dart';

ChargeRecord recordOf(String date) => ChargeRecord(date: date);

void main() {
  group('resolveBadgeLabel 等级徽标分档', () {
    test('按门槛分档', () {
      final cases = <List<Object>>[
        [0, 'Rookie Owner'],
        [1, 'Rookie Owner'],
        [9, 'Rookie Owner'],
        [10, 'Charging Pro'],
        [49, 'Charging Pro'],
        [50, 'Veteran Owner'],
        [199, 'Veteran Owner'],
        [200, 'Legend Owner'],
        [9999, 'Legend Owner'],
      ];
      for (final testCase in cases) {
        expect(
          resolveBadgeLabel(testCase[0]),
          testCase[1],
          reason: '${testCase[0]} 条记录 → ${testCase[1]}',
        );
      }
    });

    test('null 输入兜底为 0 档', () {
      expect(resolveBadgeLabel(null), 'Rookie Owner');
    });

    test('非法数值兜底为最低档', () {
      expect(resolveBadgeLabel(-5), 'Rookie Owner');
      expect(resolveBadgeLabel(double.nan), 'Rookie Owner');
      expect(resolveBadgeLabel('abc'), 'Rookie Owner');
      // 宽松字符串不解析（防脏输入意外晋级）
      expect(resolveBadgeLabel('10'), 'Rookie Owner');
      expect(resolveBadgeLabel('10abc'), 'Rookie Owner');
    });

    test('BADGE_TIERS 按门槛升序且首档门槛为 0', () {
      expect(BADGE_TIERS[0].min, 0);
      final mins = BADGE_TIERS.map((tier) => tier.min).toList();
      final sorted = List<int>.of(mins)..sort();
      expect(sorted, mins);
    });
  });

  group('getRecordDays 累计记录天数（按日去重）', () {
    test('同日多条记录只计一天', () {
      final records = <ChargeRecord>[
        recordOf('2026-09-01'),
        recordOf('2026-09-01'),
        recordOf('2026-09-02'),
      ];

      expect(getRecordDays(records), 2);
    });

    test('跨月跨年日期分别计数', () {
      final records = <ChargeRecord>[
        recordOf('2025-12-31'),
        recordOf('2026-01-01'),
        recordOf('2026-09-27'),
      ];

      expect(getRecordDays(records), 3);
    });

    test('空数组返回 0', () {
      expect(getRecordDays(<ChargeRecord>[]), 0);
    });

    test('非数组输入返回 0', () {
      expect(getRecordDays(null), 0);
    });

    test('脏数据（非法日期/缺字段）被忽略', () {
      // Arrange：JS 测试中的 null 项与裸字符串项在 Dart 强类型下
      // 对应为 date 缺省（空串，非法）的记录，口径一致
      final records = <ChargeRecord>[
        recordOf('2026-09-01'),
        recordOf('2026-13-99'),
        recordOf(''),
        recordOf(''),
      ];

      // Act & Assert
      expect(getRecordDays(records), 1);
    });

    test('不修改入参数组', () {
      final records = <ChargeRecord>[
        recordOf('2026-09-01'),
        recordOf('2026-09-01'),
      ];

      getRecordDays(records);

      expect(records.map((r) => r.date).toList(), <String>[
        '2026-09-01',
        '2026-09-01',
      ]);
    });
  });

  group('buildBadgeProgress 徽标进度钩子', () {
    test('0 条 → 差 10 条升Charging Pro', () {
      expect(
        buildBadgeProgress(0),
        const BadgeProgress(nextLabel: 'Charging Pro', remaining: 10),
      );
    });

    test('中间档位给出下一档与差值', () {
      expect(
        buildBadgeProgress(10),
        const BadgeProgress(nextLabel: 'Veteran Owner', remaining: 40),
      );
      expect(
        buildBadgeProgress(49),
        const BadgeProgress(nextLabel: 'Veteran Owner', remaining: 1),
      );
    });

    test('已达最高档（≥200）返回 null', () {
      expect(buildBadgeProgress(200), isNull);
      expect(buildBadgeProgress(999), isNull);
    });

    test('非法输入按 0 条处理', () {
      expect(
        buildBadgeProgress('abc'),
        const BadgeProgress(nextLabel: 'Charging Pro', remaining: 10),
      );
      expect(
        buildBadgeProgress(null),
        const BadgeProgress(nextLabel: 'Charging Pro', remaining: 10),
      );
    });
  });
}
