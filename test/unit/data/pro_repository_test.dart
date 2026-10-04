import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/features/pro/data/pro_repository.dart';

import '../../helpers/fake_key_value_store.dart';
import '../../helpers/test_helpers.dart';

void main() {
  // 测试环境不加载 .env → initRevenueCat 走缺 key 分支，
  // _configured 恒 false，以下用例不会触碰真实 Purchases 平台通道。

  group('ProRepository（无 RevenueCat key 分支）', () {
    test('sdkAvailable 为 false', () {
      final repo = ProRepository(FakeKeyValueStore());

      expect(repo.sdkAvailable, isFalse);
    });

    test('缓存读取：无缓存按 false 处理', () {
      final repo = ProRepository(FakeKeyValueStore());

      expect(repo.getCachedProStatus(), isFalse);
    });

    test('缓存读取：true / 脏数据口径', () {
      final kv = FakeKeyValueStore();
      final repo = ProRepository(kv);

      kv.setJson(ProRepository.storageKey, true);
      expect(repo.getCachedProStatus(), isTrue);

      kv.setJson(ProRepository.storageKey, 'yes');
      expect(repo.getCachedProStatus(), isFalse);
    });

    test('refresh / getOfferings / purchase / restore 静默不抛', () async {
      final repo = ProRepository(FakeKeyValueStore());

      expect(await repo.refresh(), isFalse);
      expect(await repo.getOfferings(), isEmpty);
      expect(await repo.restore(), isFalse);
    });
  });

  group('proStatusProvider（无 key → 恒解锁）', () {
    test('build 返回 true（dev 模式全功能解锁）', () {
      final container = createContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(FakeKeyValueStore()),
        ],
      );

      expect(container.read(proStatusProvider), isTrue);
    });

    test('applyFromRevenueCat 乐观更新 state', () {
      final container = createContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(FakeKeyValueStore()),
        ],
      );

      container.read(proStatusProvider.notifier).applyFromRevenueCat(false);

      expect(container.read(proStatusProvider), isFalse);
    });
  });
}
