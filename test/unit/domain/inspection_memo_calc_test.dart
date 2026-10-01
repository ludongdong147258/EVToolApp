import 'package:ev_tool_app/core/domain/inspection_memo_calc.dart';
import 'package:flutter_test/flutter_test.dart';

/* 固定「今天」为 2026-08-25，保证天数断言稳定（Dart 月份 1 起，无 JS 的 0 起） */
final DateTime now = DateTime(2026, 8, 25);

void main() {
  group('parseDateStr', () {
    test('解析合法日期为本地时区日期', () {
      // Arrange
      const value = '2024-06-01';
      // Act
      final date = parseDateStr(value);
      // Assert
      if (date == null) {
        fail('date should not be null');
      }
      expect(date.year, 2024);
      expect(date.month, 6);
      expect(date.day, 1);
    });

    test('格式非法或不存在的日期返回 null', () {
      expect(parseDateStr('2024-6-1'), isNull);
      expect(parseDateStr(''), isNull);
      expect(parseDateStr(null), isNull);
      expect(parseDateStr(20240601), isNull);
      expect(parseDateStr('2025-02-29'), isNull); // 2025 非闰年
    });
  });

  group('addMonths / addYears', () {
    test('月末收敛：2024-01-31 + 1 月 → 2024-02-29', () {
      expect(addMonths('2024-01-31', 1), '2024-02-29');
    });

    test('跨年：2023-12-15 + 13 月 → 2025-01-15', () {
      expect(addMonths('2023-12-15', 13), '2025-01-15');
    });

    test('闰年收敛：2024-02-29 + 1 年 → 2025-02-28', () {
      expect(addYears('2024-02-29', 1), '2025-02-28');
    });

    test('普通日期加年不变日月', () {
      expect(addYears('2023-01-31', 1), '2024-01-31');
    });

    test('加 0 返回原日期字符串', () {
      expect(addYears('2024-02-29', 0), '2024-02-29');
    });

    test('入参非法返回 null', () {
      expect(addMonths('bad', 1), isNull);
      expect(addYears('2024-02-29', double.nan), isNull);
    });
  });

  group('diffDays', () {
    test('明天为 1、今天为 0、昨天为 -1', () {
      expect(diffDays('2026-08-26', now), 1);
      expect(diffDays('2026-08-25', now), 0);
      expect(diffDays('2026-08-24', now), -1);
    });

    test('跨月跨年天数正确', () {
      expect(diffDays('2026-09-01', now), 7);
      expect(diffDays('2027-08-25', now), 365);
    });

    test('入参非法返回 null', () {
      expect(diffDays('bad', now), isNull);
    });
  });

  group('formatCnDate', () {
    test('同年显示月日，跨年带年份', () {
      expect(formatCnDate('2026-09-15', now), '9月15日');
      expect(formatCnDate('2027-08-25', now), '2027年8月25日');
    });

    test('非法输入原样返回（兜底展示）', () {
      expect(formatCnDate('bad', now), 'bad');
      expect(formatCnDate('', now), '');
    });
  });

  group('calcInspectionSchedule', () {
    test('上牌日期非法返回 null', () {
      expect(calcInspectionSchedule('bad', now), isNull);
      expect(calcInspectionSchedule('', now), isNull);
    });

    test('1 年车龄：下一个节点为第 2 年申领检验标志', () {
      // Arrange
      const registrationDate = '2025-08-25';
      // Act
      final schedule = calcInspectionSchedule(registrationDate, now);
      // Assert
      final next = schedule?.next;
      if (schedule == null || next == null) {
        fail('schedule.next should not be null');
      }
      expect(next.key, 'y2');
      expect(next.type, 'badge');
      expect(next.typeLabel, '申领检验标志');
      expect(next.daysRemaining, 365);
      expect(next.status, 'normal');
      expect(schedule.latestPast, isNull);
    });

    test('3 年车龄：下一个节点为第 4 年，第 2 年为最近已过节点', () {
      final schedule = calcInspectionSchedule('2023-08-25', now);
      final next = schedule?.next;
      final latestPast = schedule?.latestPast;
      if (schedule == null || next == null || latestPast == null) {
        fail('schedule.next/latestPast should not be null');
      }
      expect(next.key, 'y4');
      expect(next.type, 'badge');
      expect(latestPast.key, 'y2');
      expect(latestPast.status, 'overdue');
    });

    test('5 年车龄：下一个节点为第 6 年上线检测', () {
      final schedule = calcInspectionSchedule('2021-08-25', now);
      final next = schedule?.next;
      if (schedule == null || next == null) {
        fail('schedule.next should not be null');
      }
      expect(next.key, 'y6');
      expect(next.type, 'online');
      expect(next.typeLabel, '上线检测');
    });

    test('距下次年检不超过 30 天时状态为 soon', () {
      final schedule = calcInspectionSchedule('2024-09-15', now);
      final next = schedule?.next;
      if (schedule == null || next == null) {
        fail('schedule.next should not be null');
      }
      expect(next.key, 'y2');
      expect(next.dueDate, '2026-09-15');
      expect(next.daysRemaining, 21);
      expect(next.status, 'soon');
    });

    test('9 年车龄走到第 10 年节点，12 年车龄（当日满 12 年）进入年度检测区间', () {
      final nineNext = calcInspectionSchedule('2017-08-25', now)?.next;
      final twelveNext = calcInspectionSchedule('2014-08-25', now)?.next;
      if (nineNext == null || twelveNext == null) {
        fail('schedules should not be null');
      }
      expect(nineNext.key, 'y10');
      expect(twelveNext.key, 'y12');
    });

    test('里程碑按年份升序、无重复、第 30 年封顶', () {
      final schedule = calcInspectionSchedule('2020-01-01', now);
      if (schedule == null) {
        fail('schedule should not be null');
      }
      final yearsList = [for (final item in schedule.milestones) item.years];
      expect(yearsList.toSet().length, yearsList.length);
      final sorted = [...yearsList]..sort();
      expect(yearsList, sorted);
      expect(yearsList.last, 30);
      /* 第 11 年起均为每年上线 */
      final annual = schedule.milestones
          .where((item) => item.years > 10)
          .toList();
      expect(annual.every((item) => item.type == 'online'), isTrue);
    });

    test('周期起点：首个节点为上牌日，其后为上一节点到期日', () {
      final schedule = calcInspectionSchedule('2025-08-25', now);
      if (schedule == null) {
        fail('schedule should not be null');
      }
      final milestones = schedule.milestones;
      expect(milestones[0].cycleStartDate, '2025-08-25');
      expect(milestones[1].cycleStartDate, milestones[0].dueDate);
      expect(milestones[2].cycleStartDate, milestones[1].dueDate);
    });

    test('进度：1 年车龄时 next（y2）约走过一半，且 clamp 在 [0,1]', () {
      // Arrange
      const registrationDate = '2025-08-25';
      // Act
      final schedule = calcInspectionSchedule(registrationDate, now);
      final next = schedule?.next;
      // Assert
      if (schedule == null || next == null) {
        fail('schedule.next should not be null');
      }
      expect(next.key, 'y2');
      expect(next.progress, greaterThan(0.49));
      expect(next.progress, lessThan(0.51));
      /* 已过节点 progress 应为 1（用有已过节点的车龄验证），未开始的不越界 */
      final withPast = calcInspectionSchedule('2023-08-25', now);
      if (withPast == null) {
        fail('withPast should not be null');
      }
      final past = withPast.milestones
          .where((item) => item.daysRemaining < 0)
          .firstOrNull;
      if (past == null) {
        fail('past milestone should not be null');
      }
      expect(past.progress, 1);
      for (final item in schedule.milestones) {
        expect(item.progress, greaterThanOrEqualTo(0));
        expect(item.progress, lessThanOrEqualTo(1));
      }
    });
  });

  group('calcMaintenanceNodes', () {
    test('里程缺失、为 0、超界或日期非法时返回 null', () {
      expect(calcMaintenanceNodes('2025-08-25', null, now), isNull);
      expect(calcMaintenanceNodes('2025-08-25', 0, now), isNull);
      expect(calcMaintenanceNodes('2025-08-25', mileageMax + 1, now), isNull);
      expect(calcMaintenanceNodes('bad', 10000, now), isNull);
    });

    test('返回全部节点且 id 齐全', () {
      final nodes = calcMaintenanceNodes('2025-08-25', 9500, now);
      if (nodes == null) {
        fail('nodes should not be null');
      }
      expect(
        nodes.map((node) => node.id).toList(),
        maintenanceNodes.map((node) => node.id).toList(),
      );
    });

    test('里程 9500：三电检查临近（剩 500km），冷却液按里程正常', () {
      // Arrange（上牌 2026-01-15，时间周期未到，隔离验证里程周期）
      const registrationDate = '2026-01-15';
      const mileageKm = 9500;
      // Act
      final nodes = calcMaintenanceNodes(registrationDate, mileageKm, now);
      // Assert
      if (nodes == null) {
        fail('nodes should not be null');
      }
      final powertrain = nodes
          .where((node) => node.id == 'powertrain')
          .firstOrNull;
      if (powertrain == null) {
        fail('powertrain should not be null');
      }
      expect(powertrain.nextDueKm, 10000);
      expect(powertrain.kmRemaining, 500);
      expect(powertrain.status, 'soon');
      final coolant = nodes.where((node) => node.id == 'coolant').firstOrNull;
      if (coolant == null) {
        fail('coolant should not be null');
      }
      expect(coolant.nextDueKm, 40000);
      expect(coolant.kmRemaining, 30500);
      expect(coolant.status, 'normal');
    });

    test('里程恰好整除周期（40000）时该节点已到期', () {
      final nodes = calcMaintenanceNodes('2025-08-25', 40000, now);
      if (nodes == null) {
        fail('nodes should not be null');
      }
      final coolant = nodes.where((node) => node.id == 'coolant').firstOrNull;
      if (coolant == null) {
        fail('coolant should not be null');
      }
      expect(coolant.nextDueKm, 40000);
      expect(coolant.kmRemaining, 0);
      expect(coolant.status, 'overdue');
    });

    test('日期周期到当日即已到期，过期周期递进到下一个未过期节点', () {
      /* 上牌 2024-08-25：冷却液 2 年周期恰于今天（2026-08-25）到期 → 已到期 */
      final dueToday = calcMaintenanceNodes('2024-08-25', 5000, now);
      if (dueToday == null) {
        fail('dueToday should not be null');
      }
      final coolant = dueToday
          .where((node) => node.id == 'coolant')
          .firstOrNull;
      if (coolant == null) {
        fail('coolant should not be null');
      }
      expect(coolant.nextDueDate, '2026-08-25');
      expect(coolant.daysRemaining, 0);
      expect(coolant.status, 'overdue');
      /* 上牌 2023-01-01：冷却液 2025-01-01 已过，递进到 2027-01-01 */
      final advanced = calcMaintenanceNodes('2023-01-01', 5000, now);
      if (advanced == null) {
        fail('advanced should not be null');
      }
      final advancedCoolant = advanced
          .where((node) => node.id == 'coolant')
          .firstOrNull;
      if (advancedCoolant == null) {
        fail('advancedCoolant should not be null');
      }
      expect(advancedCoolant.nextDueDate, '2027-01-01');
      expect(advancedCoolant.status, 'normal');
      final powertrain = advanced
          .where((node) => node.id == 'powertrain')
          .firstOrNull;
      if (powertrain == null) {
        fail('powertrain should not be null');
      }
      expect(powertrain.nextDueDate, '2027-01-01');
      expect(powertrain.status, 'normal');
    });

    test('轮胎按年限：到期日为已到期，半年内为临近，更远为正常', () {
      // 到期日恰为今天（2026-08-25）→ 已到期
      final overdue = calcMaintenanceNodes('2021-08-25', 10000, now);
      // 2026-12-25 到期，剩 122 天 ≤ 180 → 临近
      final soon = calcMaintenanceNodes('2021-12-25', 10000, now);
      // 2027-08-25 到期，剩 365 天 → 正常
      final normal = calcMaintenanceNodes('2022-08-25', 10000, now);
      if (overdue == null || soon == null || normal == null) {
        fail('nodes should not be null');
      }
      final overdueTire = overdue
          .where((node) => node.id == 'tireReplace')
          .firstOrNull;
      if (overdueTire == null) {
        fail('overdueTire should not be null');
      }
      expect(overdueTire.nextDueDate, '2026-08-25');
      expect(overdueTire.daysRemaining, 0);
      expect(overdueTire.status, 'overdue');
      final soonTire = soon
          .where((node) => node.id == 'tireReplace')
          .firstOrNull;
      if (soonTire == null) {
        fail('soonTire should not be null');
      }
      expect(soonTire.daysRemaining, 122);
      expect(soonTire.status, 'soon');
      final normalTire = normal
          .where((node) => node.id == 'tireReplace')
          .firstOrNull;
      if (normalTire == null) {
        fail('normalTire should not be null');
      }
      expect(normalTire.daysRemaining, 365);
      expect(normalTire.status, 'normal');
      /* 纯年限节点不带里程周期 */
      expect(normalTire.nextDueKm, isNull);
      expect(normalTire.kmRemaining, isNull);
    });

    test('提示文案包含周期说明与下次触发条件', () {
      final nodes = calcMaintenanceNodes('2026-01-15', 9500, now);
      if (nodes == null) {
        fail('nodes should not be null');
      }
      final coolant = nodes.where((node) => node.id == 'coolant').firstOrNull;
      if (coolant == null) {
        fail('coolant should not be null');
      }
      expect(coolant.hint, '每 4 万公里 / 2 年 · 再行驶 30500 公里或 2028-01-15 前');
      final tire = nodes.where((node) => node.id == 'tireReplace').firstOrNull;
      if (tire == null) {
        fail('tire should not be null');
      }
      expect(tire.hint, '建议 5 年内更换 · 2031-01-15 前');
    });
  });

  group('normalizeStoredMemo', () {
    const validMemo = MemoInput(
      id: 'memo-1',
      vehicleId: 'vehicle-1',
      vehicleName: '我的电车',
      registrationDate: '2024-06-01',
      mileageKm: 12345,
      createdAt: 1750000000000,
      updatedAt: 1750000000001,
    );

    test('合法数据通过并按白名单拷贝（剔除未知字段）', () {
      final memo = normalizeStoredMemo(validMemo);
      if (memo == null) {
        fail('memo should not be null');
      }
      expect(memo.id, 'memo-1');
      expect(memo.vehicleId, 'vehicle-1');
      expect(memo.vehicleName, '我的电车');
      expect(memo.registrationDate, '2024-06-01');
      expect(memo.mileageKm, 12345);
      expect(memo.insuranceExpiryDate, isNull);
      expect(memo.createdAt, 1750000000000);
      expect(memo.updatedAt, 1750000000001);
    });

    test('缺少 id / vehicleId、日期坏、里程越界、时间戳非法均返回 null', () {
      expect(normalizeStoredMemo(validMemo.copyWith(id: '')), isNull);
      // JS 侧 vehicleId 为 null（falsy）；Dart 以空串表达同一脏数据形态
      expect(normalizeStoredMemo(validMemo.copyWith(vehicleId: '')), isNull);
      expect(
        normalizeStoredMemo(validMemo.copyWith(registrationDate: 'bad')),
        isNull,
      );
      expect(normalizeStoredMemo(validMemo.copyWith(mileageKm: 0)), isNull);
      expect(
        normalizeStoredMemo(validMemo.copyWith(mileageKm: mileageMax + 1)),
        isNull,
      );
      expect(normalizeStoredMemo(validMemo.copyWith(createdAt: 0)), isNull);
      expect(normalizeStoredMemo(null), isNull);
    });

    test('vehicleName 缺省时回退为空字符串（车辆被删后快照仍可用）', () {
      final memo = normalizeStoredMemo(
        const MemoInput(
          id: 'memo-1',
          vehicleId: 'vehicle-1',
          registrationDate: '2024-06-01',
          mileageKm: 12345,
          createdAt: 1750000000000,
          updatedAt: 1750000000001,
        ),
      );
      if (memo == null) {
        fail('memo should not be null');
      }
      expect(memo.vehicleName, '');
    });

    test('保险到期日为选填：存量无字段/脏数据归一为 null，合法值透传', () {
      // Arrange & Act & Assert
      final without = normalizeStoredMemo(validMemo);
      final dirty = normalizeStoredMemo(
        validMemo.copyWith(insuranceExpiryDate: 'bad'),
      );
      final valid = normalizeStoredMemo(
        validMemo.copyWith(insuranceExpiryDate: '2027-06-01'),
      );
      if (without == null || dirty == null || valid == null) {
        fail('memos should not be null');
      }
      expect(without.insuranceExpiryDate, isNull);
      expect(dirty.insuranceExpiryDate, isNull);
      expect(valid.insuranceExpiryDate, '2027-06-01');
    });
  });

  group('calcInsuranceStatus 保险到期状态', () {
    final insNow = DateTime(2026, 9, 19); // 2026-09-19

    test('未记录 / 非法日期返回 null', () {
      // Arrange & Act & Assert
      expect(calcInsuranceStatus(null, insNow), isNull);
      expect(calcInsuranceStatus('', insNow), isNull);
      expect(calcInsuranceStatus('2026-13-01', insNow), isNull);
    });

    test('剩余 30 天为即将到期（soon），31 天为正常', () {
      // Arrange：2026-10-19 距今 30 天、2026-10-20 距今 31 天
      final soon = calcInsuranceStatus('2026-10-19', insNow);
      final normal = calcInsuranceStatus('2026-10-20', insNow);

      // Act & Assert
      if (soon == null || normal == null) {
        fail('statuses should not be null');
      }
      expect(soon.status, 'soon');
      expect(soon.daysRemaining, 30);
      expect(normal.status, 'normal');
    });

    test('当天到期（0 天）按 soon 处理，昨天到期为 overdue', () {
      // Arrange
      final today = calcInsuranceStatus('2026-09-19', insNow);
      final yesterday = calcInsuranceStatus('2026-09-18', insNow);

      // Act & Assert
      if (today == null || yesterday == null) {
        fail('statuses should not be null');
      }
      expect(today.status, 'soon');
      expect(today.daysRemaining, 0);
      expect(yesterday.status, 'overdue');
      expect(yesterday.daysRemaining, -1);
    });

    test('返回体携带原始到期日', () {
      // Arrange & Act
      final result = calcInsuranceStatus('2027-01-10', insNow);

      // Assert
      if (result == null) {
        fail('result should not be null');
      }
      expect(result.expiryDate, '2027-01-10');
    });
  });

  group('静态科普内容', () {
    test('SCIENCE_SECTIONS 结构齐备', () {
      expect(scienceSections.length, 3);
      for (final section in scienceSections) {
        expect(section.id, isA<String>());
        expect(section.icon, isA<String>());
        expect(section.title, isA<String>());
        expect(section.lines.length, greaterThan(0));
      }
    });

    test('MEMO_DISCLAIMER 非空且包含车管所提示', () {
      expect(memoDisclaimer.length, greaterThan(0));
      expect(memoDisclaimer.contains('车管所'), isTrue);
    });
  });
}
