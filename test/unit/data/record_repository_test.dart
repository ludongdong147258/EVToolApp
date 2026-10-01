import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/core/domain/charge_records.dart';
import 'package:ev_tool_app/core/domain/date_utils.dart';
import 'package:ev_tool_app/features/costs/data/repositories/cost_repository.dart';
import 'package:ev_tool_app/features/records/data/repositories/record_repository.dart';
import 'package:ev_tool_app/core/domain/vehicles.dart';
import 'package:ev_tool_app/features/vehicles/data/repositories/vehicle_repository.dart';

import '../../helpers/fake_key_value_store.dart';

ChargeRecord _record(String id, String date, {String type = 'fast'}) {
  return ChargeRecord(
    id: id,
    type: type,
    date: date,
    cost: 30,
    energy: 40,
    createdAt: 1,
  );
}

void main() {
  late FakeKeyValueStore kv;
  late RecordRepository repo;

  setUp(() {
    kv = FakeKeyValueStore();
    repo = RecordRepository(kv);
  });

  group('RecordRepository（移植 recordService.test.js 核心）', () {
    test('getRecords 空存储返回空数组', () {
      expect(repo.getRecords(), isEmpty);
    });

    test('addRecord 前插并可读回；按日期降序、同日按 createdAt 降序', () async {
      await repo.addRecord(_record('r1', '2026-08-01').copyWith(createdAt: 1));
      await repo.addRecord(_record('r2', '2026-08-03').copyWith(createdAt: 1));
      await repo.addRecord(_record('r3', '2026-08-01').copyWith(createdAt: 5));

      final records = repo.getRecords();
      // 同日按 createdAt 降序（r3 > r1）
      expect(records.map((r) => r.id).toList(), ['r2', 'r3', 'r1']);
    });

    test('updateRecord 保留 id 与 createdAt；id 不存在时幂等', () async {
      await repo.addRecord(
        _record('r1', '2026-08-01').copyWith(createdAt: 100),
      );
      await repo.updateRecord(
        'r1',
        _record('changed', '2026-08-02').copyWith(createdAt: 999),
      );
      final updated = repo.getRecords().single;
      expect(updated.id, 'r1');
      expect(updated.createdAt, 100);
      expect(updated.date, '2026-08-02');

      await repo.updateRecord('missing', _record('x', '2026-01-01'));
      expect(repo.getRecords(), hasLength(1));
    });

    test('removeRecord 删除且幂等', () async {
      await repo.addRecord(_record('r1', '2026-08-01'));
      await repo.addRecord(_record('r2', '2026-08-02'));
      var records = await repo.removeRecord('r1');
      expect(records.map((r) => r.id).toList(), ['r2']);
      records = await repo.removeRecord('r1');
      expect(records, hasLength(1));
    });

    test('脏数据逐条过滤（无 id / 非法类型 / cost≤0 / energy≤0）', () {
      kv.setJson(RecordRepository.storageKey, [
        {
          'id': 'ok',
          'type': 'fast',
          'date': '2026-08-01',
          'cost': 1,
          'energy': 2,
        },
        {'type': 'fast', 'date': '2026-08-01', 'cost': 1, 'energy': 2},
        {
          'id': 'bad-type',
          'type': 'slow',
          'date': '2026-08-01',
          'cost': 1,
          'energy': 2,
        },
        {
          'id': 'bad-cost',
          'type': 'fast',
          'date': '2026-08-01',
          'cost': 0,
          'energy': 2,
        },
        {
          'id': 'bad-energy',
          'type': 'fast',
          'date': '2026-08-01',
          'cost': 1,
          'energy': -1,
        },
        'junk',
      ]);
      final records = repo.getRecords();
      expect(records.map((r) => r.id).toList(), ['ok']);
    });

    test('importRecords 按 id 去重，仅添加本地不存在的条目', () async {
      await repo.addRecord(_record('r1', '2026-08-01'));
      final pick = await repo.importRecords([
        _record('r1', '2026-08-01'),
        _record('r2', '2026-08-02'),
      ]);
      expect(pick.toAdd.map((r) => r.id).toList(), ['r2']);
      expect(pick.skippedCount, 1);
      expect(repo.getRecords(), hasLength(2));
    });

    test('getRecordsForMonth 按月过滤', () async {
      await repo.addRecord(_record('r1', '2026-08-01'));
      await repo.addRecord(_record('r2', '2026-09-01'));
      final august = repo.getRecordsForMonth('2026-08');
      expect(august.map((r) => r.id).toList(), ['r1']);
    });

    test('syncVehicleRename / syncVehicleRemoval 同步快照', () async {
      await repo.addRecord(
        _record(
          'r1',
          '2026-08-01',
        ).copyWith(vehicleId: 'v1', vehicleName: '旧名'),
      );
      await repo.syncVehicleRename('v1', '新名');
      expect(repo.getRecords().single.vehicleName, '新名');

      await repo.syncVehicleRemoval('v1');
      final cleared = repo.getRecords().single;
      expect(cleared.vehicleId, isNull);
      expect(cleared.vehicleName, isNull);
    });

    test('往返：getMonthKey 兼容月度统计', () async {
      await repo.addRecord(_record('r1', '2026-08-15'));
      final monthKeys = [
        for (final r in repo.getRecords()) getMonthKey(r.date),
      ];
      expect(monthKeys, ['2026-08']);
    });
  });

  group('VehicleRepository（不变式 + 快照联动）', () {
    late VehicleRepository vehicleRepo;

    setUp(() {
      vehicleRepo = VehicleRepository(kv, repo, CostRepository(kv));
    });

    Vehicle makeVehicle(String id, String name) => Vehicle(
      id: id,
      name: name,
      battery: 60,
      note: '',
      photoPath: '',
      isDefault: false,
      createdAt: 1,
      updatedAt: 1,
    );

    test('首台车强制默认；读取维持「恰有一台默认车」不变式', () async {
      await vehicleRepo.addVehicle(makeVehicle('v1', '小白'));
      await vehicleRepo.addVehicle(makeVehicle('v2', '小黑'));
      expect(vehicleRepo.getVehicles().first.isDefault, isTrue);
      expect(vehicleRepo.getVehicles().where((v) => v.isDefault).length, 1);

      // 删除默认车后默认标记自动落到剩余车
      await vehicleRepo.removeVehicle('v1');
      expect(vehicleRepo.getVehicles().single.isDefault, isTrue);
    });

    test('改名同步充电记录 vehicleName 快照', () async {
      await vehicleRepo.addVehicle(makeVehicle('v1', '小白'));
      await repo.addRecord(
        _record(
          'r1',
          '2026-08-01',
        ).copyWith(vehicleId: 'v1', vehicleName: '小白'),
      );
      await vehicleRepo.updateVehicle('v1', name: '大白');
      expect(repo.getRecords().single.vehicleName, '大白');
    });

    test('删除车辆清空关联记录快照', () async {
      await vehicleRepo.addVehicle(makeVehicle('v1', '小白'));
      await repo.addRecord(
        _record(
          'r1',
          '2026-08-01',
        ).copyWith(vehicleId: 'v1', vehicleName: '小白'),
      );
      await vehicleRepo.removeVehicle('v1');
      expect(repo.getRecords().single.vehicleId, isNull);
    });

    test('setDefault 幂等切换', () async {
      await vehicleRepo.addVehicle(makeVehicle('v1', '小白'));
      await vehicleRepo.addVehicle(makeVehicle('v2', '小黑'));
      await vehicleRepo.setDefault('v2');
      final vehicles = vehicleRepo.getVehicles();
      expect(vehicles.firstWhere((v) => v.id == 'v2').isDefault, isTrue);
      expect(vehicles.firstWhere((v) => v.id == 'v1').isDefault, isFalse);
    });
  });
}
