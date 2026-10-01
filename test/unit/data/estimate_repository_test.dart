import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/core/domain/home_charger_calc.dart';
import 'package:ev_tool_app/features/records/data/repositories/record_repository.dart';
import 'package:ev_tool_app/features/tools/data/repositories/estimate_repository.dart';

import '../../helpers/fake_key_value_store.dart';

/// 写入必失败的存储（模拟磁盘满）。
class FailingWriteStore extends FakeKeyValueStore {
  @override
  Future<void> setString(String key, String value) async {
    throw Exception('disk full');
  }

  @override
  Future<void> setJson(String key, Object? value) async {
    throw Exception('disk full');
  }
}

const Map<String, bool> _entryConditions = {
  'undergroundGarage': true,
  'groundSpot': false,
};

StoredEstimate buildEntry({
  String id = 'e1',
  num savedAt = 1754000000000,
  int cableLength = 30,
}) {
  const estimate = InstallEstimate(
    basePrice: 2850,
    extraCableLength: 0,
    extraCableCost: 0,
    surcharges: [Surcharge(id: 'undergroundGarage', price: 200)],
    surchargeTotal: 200,
    total: 3050,
  );
  return StoredEstimate(
    id: id,
    cableLength: cableLength,
    powerId: '7kw',
    spot: 'undergroundGarage',
    conditions: _entryConditions,
    estimate: estimate,
    savedAt: savedAt,
  );
}

void main() {
  late FakeKeyValueStore kv;
  late EstimateRepository repo;

  setUp(() {
    kv = FakeKeyValueStore();
    repo = EstimateRepository(kv);
  });

  group('EstimateRepository（移植 estimateService.test.js）', () {
    test('空 storage 返回空数组', () {
      expect(repo.getEstimates(), isEmpty);
    });

    test('兼容旧版单对象形态（补合成 id 包成数组并保留）', () {
      kv.setJson(
        EstimateRepository.storageKey,
        storedEstimateToJson(buildEntry(savedAt: 1754000000000))..remove('id'),
      );
      final estimates = repo.getEstimates();
      expect(estimates, hasLength(1));
      expect(estimates.first.id, 'legacy-1754000000000');
      expect(estimates.first.savedAt, 1754000000000);
    });

    test('脏数据被过滤并按保存时间降序', () async {
      await repo.saveEstimate(buildEntry(id: 'first', savedAt: 2000));
      final stored = kv.getJsonList(EstimateRepository.storageKey) ?? [];
      final first = stored.first as Map<String, dynamic>;
      await kv.setJson(EstimateRepository.storageKey, [
        {'junk': true},
        first,
        {...first, 'id': 'older', 'savedAt': 1000},
      ]);
      final estimates = repo.getEstimates();
      expect(estimates, hasLength(2));
      expect(estimates.first.id, 'first');
      expect(estimates.last.id, 'older');
    });

    test('读出时用入参重算 estimate（篡改金额被校验和纠正）', () async {
      await repo.saveEstimate(buildEntry());
      final stored = kv.getJsonList(EstimateRepository.storageKey) ?? [];
      final tampered = stored.first as Map<String, dynamic>;
      (tampered['estimate'] as Map<String, dynamic>)['total'] = 999999;
      await kv.setJson(EstimateRepository.storageKey, stored);

      final estimates = repo.getEstimates();
      expect(estimates, hasLength(1));
      expect(estimates.first.estimate.total, 3050);
    });

    test('前插并落盘，带 id 与 savedAt', () async {
      final estimates = await repo.saveEstimate(buildEntry());
      expect(estimates, hasLength(1));
      expect(estimates.first.id, isNotEmpty);
      expect(estimates.first.savedAt, greaterThan(0));
      expect(kv.getJsonList(EstimateRepository.storageKey), hasLength(1));
    });

    test('最多保留 20 条，超出截断最旧的', () async {
      for (var i = 0; i < 25; i += 1) {
        await repo.saveEstimate(buildEntry(id: 'e$i', savedAt: 1000 + i));
      }
      final estimates = repo.getEstimates();
      expect(estimates, hasLength(20));
      expect(estimates.first.id, 'e24');
      expect(estimates.last.id, 'e5');
    });

    test('写入失败时抛中文错误', () {
      final failing = EstimateRepository(FailingWriteStore());
      expect(
        failing.saveEstimate(buildEntry()),
        throwsA(
          isA<StorageException>().having((e) => e.message, 'message', '保存失败'),
        ),
      );
    });

    test('按 id 删除', () async {
      await repo.saveEstimate(buildEntry());
      final id =
          (kv.getJsonList(EstimateRepository.storageKey) ?? []).first
              as Map<String, dynamic>;
      final estimates = await repo.removeEstimate(id['id'] as String);
      expect(estimates, isEmpty);
    });

    test('id 不存在时幂等 no-op', () async {
      await repo.saveEstimate(buildEntry());
      expect(await repo.removeEstimate('missing'), hasLength(1));
    });
  });
}
