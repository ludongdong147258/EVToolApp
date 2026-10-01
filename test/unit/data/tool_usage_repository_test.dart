import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/features/tools/data/repositories/tool_usage_repository.dart';

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

void main() {
  late FakeKeyValueStore kv;
  late ToolUsageRepository repo;

  setUp(() {
    kv = FakeKeyValueStore();
    repo = ToolUsageRepository(kv);
  });

  group('ToolUsageRepository（移植 toolUsageService.test.js）', () {
    test('无记录时返回空数组', () {
      expect(repo.getRecentToolIds(), isEmpty);
    });

    test('使用记录置顶去重并落盘', () {
      repo.trackToolUse('a');
      repo.trackToolUse('b');
      repo.trackToolUse('a');

      expect(repo.getRecentToolIds(), ['a', 'b']);
    });

    test('超过上限 3 个时截断最旧的', () {
      repo.trackToolUse('a');
      repo.trackToolUse('b');
      repo.trackToolUse('c');
      repo.trackToolUse('d');

      expect(repo.getRecentToolIds(), ['d', 'c', 'b']);
    });

    test('脏 storage 数据被过滤', () {
      kv.setJson(ToolUsageRepository.storageKey, ['ok', 3, null, '']);

      expect(repo.getRecentToolIds(), ['ok']);
    });

    test('写失败不抛错（非关键数据）', () async {
      final failing = ToolUsageRepository(FailingWriteStore());

      await failing.trackToolUse('a');

      // 写入失败仅 log，不抛错；storage 中无记录（与 JS 读取口径一致）
      expect(failing.getRecentToolIds(), isEmpty);
    });
  });
}
