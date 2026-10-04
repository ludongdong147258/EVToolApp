import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/core/constants/app_constants.dart';
import 'package:ev_tool_app/features/ocr/data/ocr_usage_repository.dart';

import '../../helpers/fake_key_value_store.dart';

/// 写入必失败的存储（模拟磁盘满）。
class FailingWriteStore extends FakeKeyValueStore {
  @override
  Future<void> setJson(String key, Object? value) async {
    throw Exception('disk full');
  }
}

void main() {
  late FakeKeyValueStore kv;
  late OcrUsageRepository repo;

  setUp(() {
    kv = FakeKeyValueStore();
    repo = OcrUsageRepository(kv);
  });

  group('OcrUsageRepository', () {
    test('无记录时用量为 0 且有额度', () {
      expect(repo.usedThisMonth(), 0);
      expect(repo.remaining(), AppConstants.freeOcrMonthlyQuota);
      expect(repo.hasQuota(), isTrue);
    });

    test('increment 计数并落盘', () async {
      await repo.increment();
      await repo.increment();

      expect(repo.usedThisMonth(), 2);
      expect(repo.remaining(), AppConstants.freeOcrMonthlyQuota - 2);
    });

    test('用量达到免费额度后 hasQuota 为 false', () async {
      for (var i = 0; i < AppConstants.freeOcrMonthlyQuota; i++) {
        await repo.increment();
      }

      expect(repo.hasQuota(), isFalse);
      expect(repo.remaining(), 0);
    });

    test('超额后 remaining 不为负', () async {
      await kv.setJson(OcrUsageRepository.storageKey, {
        'month': _monthKey(DateTime(2026, 10, 15)),
        'count': 99,
      });

      expect(repo.remaining(now: DateTime(2026, 10, 20)), 0);
    });

    test('跨月自动归零', () async {
      await repo.increment(now: DateTime(2026, 9, 30));

      expect(repo.usedThisMonth(now: DateTime(2026, 10, 1)), 0);
      expect(repo.hasQuota(now: DateTime(2026, 10, 1)), isTrue);
    });

    test('同月不同日均计入当月', () async {
      await repo.increment(now: DateTime(2026, 10, 1));
      await repo.increment(now: DateTime(2026, 10, 31));

      expect(repo.usedThisMonth(now: DateTime(2026, 10, 15)), 2);
    });

    test('脏数据容错：count 非法按 0 处理', () async {
      await kv.setJson(OcrUsageRepository.storageKey, {
        'month': _monthKey(DateTime(2026, 10, 15)),
        'count': 'many',
      });

      expect(repo.usedThisMonth(now: DateTime(2026, 10, 20)), 0);
    });

    test('脏数据容错：损坏 JSON 按 0 处理', () {
      kv.setRaw(OcrUsageRepository.storageKey, '{not-json');

      expect(repo.usedThisMonth(), 0);
    });

    test('写失败不抛错（非关键数据）', () async {
      final failing = OcrUsageRepository(FailingWriteStore());

      await failing.increment();

      expect(failing.usedThisMonth(), 0);
    });
  });
}

/// 与 getCurrentMonthKey 相同的 yyyy-MM 格式（测试内自证，避免依赖实现）。
String _monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
