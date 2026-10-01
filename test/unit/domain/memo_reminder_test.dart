import 'package:ev_tool_app/core/domain/inspection_memo_calc.dart';
import 'package:ev_tool_app/core/domain/memo_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

/* 固定「今天」为 2026-10-15，构造相对今天偏移的备忘（Dart 月份 1 起） */
final DateTime now = DateTime(2026, 10, 15);

/// 以固定“今天”构造备忘（默认值对应 buildMemo()，可按需覆盖）
MemoItem buildMemo({
  String id = 'm1',
  String vehicleId = 'v1',
  String vehicleName = '小鹏P7',
  String registrationDate = '2024-06-10',
  int mileageKm = 20000,
  String? insuranceExpiryDate,
}) {
  return MemoItem(
    id: id,
    vehicleId: vehicleId,
    vehicleName: vehicleName,
    registrationDate: registrationDate,
    mileageKm: mileageKm,
    insuranceExpiryDate: insuranceExpiryDate,
    createdAt: 1,
    updatedAt: 2,
  );
}

void main() {
  group('pickMemoReminder 备忘到期提醒', () {
    test('无备忘 / 备忘为脏数组时返回 null', () {
      expect(pickMemoReminder(<MemoItem>[], now), isNull);
      expect(pickMemoReminder(null, now), isNull);
      expect(pickMemoReminder(<MemoItem?>[null], now), isNull);
    });

    test('全部节点状态正常时返回 null', () {
      // Arrange：上牌 1 年多、里程 2.1 万（距下一节点尚远）
      final memo = buildMemo(registrationDate: '2025-06-10', mileageKm: 21000);

      // Act & Assert
      expect(pickMemoReminder(<MemoItem>[memo], now), isNull);
    });

    test('年检临近（≤30 天）返回 soon 级提醒', () {
      // Arrange：2020-10-30 上牌 → 第 6 年上线检测 2026-10-30，距今 15 天；
      // 里程 2.9 万使维保节点同为 soon（15 天），日期类（年检）同天数优先
      final memo = buildMemo(registrationDate: '2020-10-30', mileageKm: 29000);

      // Act
      final reminder = pickMemoReminder(<MemoItem>[memo], now);

      // Assert
      if (reminder == null) {
        fail('reminder should not be null');
      }
      expect(reminder.level, 'soon');
      expect(reminder.text, '小鹏P7 · 上线检测 15 天后到期');
    });

    test('年检已过期返回 overdue 级提醒', () {
      // Arrange：第 2 年申领节点 2026-09-01 已过期 44 天
      final memo = buildMemo(registrationDate: '2024-09-01', mileageKm: 15000);

      // Act
      final reminder = pickMemoReminder(<MemoItem>[memo], now);

      // Assert
      if (reminder == null) {
        fail('reminder should not be null');
      }
      expect(reminder.level, 'overdue');
      expect(reminder.text, '小鹏P7 · 申领检验标志 已到期 44 天');
    });

    test('保险到期参与提醒（带车辆名）', () {
      // Arrange：保险 10 天后到期；年检/维保均正常
      final memo = buildMemo(
        registrationDate: '2025-06-10',
        mileageKm: 21000,
        insuranceExpiryDate: '2026-10-25',
      );

      // Act
      final reminder = pickMemoReminder(<MemoItem>[memo], now);

      // Assert
      if (reminder == null) {
        fail('reminder should not be null');
      }
      expect(reminder.level, 'soon');
      expect(reminder.text, '小鹏P7 · 车险 10 天后到期');
    });

    test('维保里程到期（kmRemaining ≤ 0）提示已到保养里程', () {
      // Arrange：里程 40000 整 → kmRemaining=0 视为到期；年检第 2 年节点 2028 年还很远
      final memo = buildMemo(registrationDate: '2026-01-10', mileageKm: 40000);

      // Act
      final reminder = pickMemoReminder(<MemoItem>[memo], now);

      // Assert
      if (reminder == null) {
        fail('reminder should not be null');
      }
      expect(reminder.level, 'overdue');
      expect(reminder.text, '小鹏P7 · 三电系统检查 已到保养里程');
    });

    test('多条备忘取最紧急（overdue 优先于 soon）', () {
      // Arrange：memoA 年检 soon（15 天），memoB 年检 overdue（44 天）
      final memoA = buildMemo(
        id: 'a',
        vehicleId: 'va',
        registrationDate: '2020-10-30',
        mileageKm: 29000,
      );
      final memoB = buildMemo(
        id: 'b',
        vehicleId: 'vb',
        vehicleName: '',
        registrationDate: '2024-09-01',
        mileageKm: 15000,
      );

      // Act
      final reminder = pickMemoReminder(<MemoItem>[memoA, memoB], now);

      // Assert
      if (reminder == null) {
        fail('reminder should not be null');
      }
      expect(reminder.level, 'overdue');
      expect(reminder.text, '申领检验标志 已到期 44 天');
    });
  });
}
