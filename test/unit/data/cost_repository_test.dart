import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/core/domain/maintenance_costs.dart';
import 'package:ev_tool_app/features/costs/data/repositories/cost_repository.dart';

import '../../helpers/fake_key_value_store.dart';

Expense _expense(
  String id,
  String date, {
  String type = 'parking',
  double amount = 20,
  String note = '',
  String? vehicleId,
  String? vehicleName,
  int createdAt = 1,
}) {
  return Expense(
    id: id,
    type: type,
    date: date,
    amount: amount,
    note: note,
    vehicleId: vehicleId,
    vehicleName: vehicleName,
    createdAt: createdAt,
  );
}

void main() {
  late FakeKeyValueStore kv;
  late CostRepository repo;

  setUp(() {
    kv = FakeKeyValueStore();
    repo = CostRepository(kv);
  });

  group('CostRepository（移植 costService.test.js 核心）', () {
    test('getExpenses 空存储 / 空数组返回空数组', () {
      expect(repo.getExpenses(), isEmpty);
      kv.setJson(CostRepository.storageKey, []);
      expect(repo.getExpenses(), isEmpty);
    });

    test('脏数据被 normalize 过滤，合法支出按日期降序', () {
      kv.setJson(CostRepository.storageKey, [
        _expense('a', '2026-08-01').toJson(),
        {'invalid': true},
        _expense('bad-type', '2026-08-01', type: 'unknown').toJson(),
        _expense('bad-date', '2026/08/01').toJson(),
        _expense('b', '2026-08-10').toJson(),
        'junk',
      ]);
      final expenses = repo.getExpenses();
      expect(expenses.map((e) => e.id).toList(), ['b', 'a']);
    });

    test('同日按 createdAt 降序', () async {
      await repo.addExpense(_expense('a', '2026-08-01', createdAt: 1));
      await repo.addExpense(_expense('b', '2026-08-01', createdAt: 5));
      await repo.addExpense(_expense('c', '2026-08-10', createdAt: 1));
      expect(repo.getExpenses().map((e) => e.id).toList(), ['c', 'b', 'a']);
    });

    test('addExpense 落盘并可读回', () async {
      await repo.addExpense(_expense('old', '2026-07-01'));
      final expenses = await repo.addExpense(_expense('new', '2026-08-20'));
      expect(expenses.map((e) => e.id).toList(), ['new', 'old']);
      expect(repo.getExpenses(), hasLength(2));
    });

    test('updateExpense 整体替换但保留 id/createdAt，日期变化后重排', () async {
      await repo.addExpense(_expense('a', '2026-08-10', createdAt: 111));
      await repo.addExpense(_expense('b', '2026-07-01', createdAt: 222));
      final expenses = await repo.updateExpense(
        'a',
        _expense('ignored', '2026-06-01', amount: 99, createdAt: 999),
      );
      // a 日期提前，排到 b 后
      expect(expenses.map((e) => e.id).toList(), ['b', 'a']);
      final updated = expenses.where((e) => e.id == 'a').first;
      expect(updated.amount, 99);
      expect(updated.createdAt, 111); // 原 createdAt 保留
    });

    test('updateExpense id 不存在时幂等返回原数组', () async {
      await repo.addExpense(_expense('a', '2026-08-01'));
      final expenses = await repo.updateExpense(
        'missing',
        _expense('x', '2026-01-01'),
      );
      expect(expenses.map((e) => e.id).toList(), ['a']);
    });

    test('removeExpense 按 id 删除且幂等', () async {
      await repo.addExpense(_expense('a', '2026-08-01'));
      await repo.addExpense(_expense('b', '2026-07-15'));
      var expenses = await repo.removeExpense('a');
      expect(expenses.map((e) => e.id).toList(), ['b']);
      expenses = await repo.removeExpense('a');
      expect(expenses.map((e) => e.id).toList(), ['b']);
    });

    test('删除后原样写回可恢复支出（id 与 createdAt 不变）', () async {
      final original = _expense('a', '2026-08-01', createdAt: 100);
      await repo.addExpense(original);
      await repo.addExpense(_expense('b', '2026-07-15', createdAt: 200));
      final deleted = repo.getExpenses().where((e) => e.id == 'a').first;

      await repo.removeExpense('a');
      await repo.addExpense(deleted);

      final restored = repo.getExpenses().where((e) => e.id == 'a').first;
      expect(restored.id, original.id);
      expect(restored.createdAt, original.createdAt);
      expect(restored.date, original.date);
      expect(restored.amount, original.amount);
      expect(repo.getExpenses().map((e) => e.id).toList(), ['a', 'b']);
    });

    test('importExpenses 按 id 去重合并并保持日期降序', () async {
      await repo.addExpense(_expense('local', '2026-08-01'));
      final pick = await repo.importExpenses([
        _expense('import-a', '2026-09-01'),
        _expense('local', '2026-08-01'), // 重复 id，跳过
      ]);
      expect(pick.toAdd.map((e) => e.id).toList(), ['import-a']);
      expect(pick.skippedCount, 1);
      expect(repo.getExpenses().map((e) => e.id).toList(), [
        'import-a',
        'local',
      ]);
    });

    test('importExpenses 全部重复时不写回', () async {
      await repo.addExpense(_expense('e1', '2026-08-01'));
      final pick = await repo.importExpenses([_expense('e1', '2026-08-01')]);
      expect(pick.toAdd, isEmpty);
      expect(pick.skippedCount, 1);
      expect(repo.getExpenses(), hasLength(1));
    });

    test('syncVehicleRename 刷新快照（trim + 截断到 20 字）且只影响目标车', () async {
      await repo.addExpense(
        _expense('a', '2026-08-01', vehicleId: 'v1', vehicleName: '旧名'),
      );
      await repo.addExpense(
        _expense('b', '2026-08-02', vehicleId: 'v2', vehicleName: '别的车'),
      );
      await repo.syncVehicleRename('v1', '  新车名带超长截断测试一二三四五六七八九十零一二  ');
      final expenses = repo.getExpenses();
      expect(
        expenses.where((e) => e.id == 'a').first.vehicleName,
        hasLength(20),
      );
      expect(expenses.where((e) => e.id == 'b').first.vehicleName, '别的车');
    });

    test('syncVehicleRemoval 置空关联支出的车辆字段', () async {
      await repo.addExpense(
        _expense('a', '2026-08-01', vehicleId: 'v1', vehicleName: '待删'),
      );
      await repo.addExpense(
        _expense('b', '2026-08-02', vehicleId: 'v2', vehicleName: '保留'),
      );
      await repo.syncVehicleRemoval('v1');
      final removed = repo.getExpenses().where((e) => e.id == 'a').first;
      expect(removed.vehicleId, isNull);
      expect(removed.vehicleName, isNull);
      expect(
        repo.getExpenses().where((e) => e.id == 'b').first.vehicleName,
        '保留',
      );
    });
  });
}
