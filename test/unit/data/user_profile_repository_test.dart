import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/core/domain/user_profile.dart';
import 'package:ev_tool_app/features/profile/data/repositories/user_profile_repository.dart';
import 'package:ev_tool_app/features/vehicles/data/photo_store.dart';

import '../../helpers/fake_key_value_store.dart';

/// 模拟磁盘写满（让 setJson 抛 Exception）。
class _DiskFullException implements Exception {}

class _FailingStore extends FakeKeyValueStore {
  @override
  Future<void> setJson(String key, Object? value) async {
    throw _DiskFullException();
  }
}

void main() {
  late FakeKeyValueStore kv;
  late Directory tempDir;
  late PhotoStore avatarStore;
  late UserProfileRepository repo;

  setUp(() async {
    kv = FakeKeyValueStore();
    tempDir = await Directory.systemTemp.createTemp('user_profile_test');
    avatarStore = PhotoStore(
      Directory('${tempDir.path}/avatars'),
      // 测试环境不做压缩（无平台通道），走原图拷贝路径
      compressor: (_, _) async => null,
    );
    repo = UserProfileRepository(kv, Future.value(avatarStore));
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// 在临时目录外层造一个“头像源文件”。
  File writeSource(String name) {
    final file = File('${tempDir.path}/$name');
    file.writeAsStringSync('fake-image-bytes');
    return file;
  }

  group('UserProfileRepository.getProfile（移植 userService jest）', () {
    test('空 storage 返回默认资料', () {
      final profile = repo.getProfile();

      expect(profile.nickname, '');
      expect(profile.avatarUrl, '');
    });

    test('storage 有数据时返回合并后的资料', () async {
      await kv.setJson(UserProfileRepository.storageKey, {
        'nickname': '阿明',
        'avatarUrl': 'wxfile://a',
      });

      final profile = repo.getProfile();

      expect(profile.nickname, '阿明');
      expect(profile.avatarUrl, 'wxfile://a');
    });

    test('脏数据字段被忽略，回落默认值', () async {
      await kv.setJson(UserProfileRepository.storageKey, {
        'nickname': 123,
        'avatarUrl': true,
      });

      final profile = repo.getProfile();

      expect(profile.nickname, isNull);
      expect(profile.avatarUrl, '');
    });
  });

  group('UserProfileRepository.saveProfile', () {
    test('合并保存：未传字段保留原值', () async {
      await kv.setJson(UserProfileRepository.storageKey, {
        'nickname': '阿明',
        'avatarUrl': 'wxfile://a',
      });

      final next = await repo.saveProfile(const ProfilePatch(nickname: '小电'));

      expect(next.nickname, '小电');
      expect(next.avatarUrl, 'wxfile://a');
      expect(kv.getJsonMap(UserProfileRepository.storageKey), next.toJson());
    });

    test('写入失败时 throw 中文错误', () {
      final failing = UserProfileRepository(
        _FailingStore(),
        Future.value(avatarStore),
      );

      expect(
        failing.saveProfile(const ProfilePatch(nickname: 'x')),
        throwsA(
          isA<ProfileStorageException>().having(
            (e) => e.message,
            'message',
            '保存失败',
          ),
        ),
      );
    });
  });

  group('UserProfileRepository.saveAvatar', () {
    test('临时文件转持久文件后入库（avatarUrl 存裸文件名）', () async {
      final source = writeSource('temp.png');

      final next = await repo.saveAvatar(source.path);

      expect(next.avatarUrl, isNotEmpty);
      // 只存裸文件名（不含目录分隔符）
      expect(next.avatarUrl.contains('/'), isFalse);
      expect(avatarStore.exists(next.avatarUrl), isTrue);
      expect(
        kv.getJsonMap(UserProfileRepository.storageKey)?['avatarUrl'],
        next.avatarUrl,
      );
    });

    test('路径无效时 throw 中文错误', () {
      expect(
        repo.saveAvatar(''),
        throwsA(
          isA<ProfileStorageException>().having(
            (e) => e.message,
            'message',
            '头像路径无效',
          ),
        ),
      );
    });

    test('换头像时删除旧持久文件', () async {
      final first = await repo.saveAvatar(writeSource('a.png').path);
      final second = await repo.saveAvatar(writeSource('b.png').path);

      expect(avatarStore.exists(first.avatarUrl), isFalse);
      expect(avatarStore.exists(second.avatarUrl), isTrue);
    });

    test('旧路径为空时不删除任何文件', () async {
      final next = await repo.saveAvatar(writeSource('a.png').path);

      expect(avatarStore.exists(next.avatarUrl), isTrue);
    });
  });

  group('normalizeNickname（领域纯函数，与存储规则一致）', () {
    test('trim + 截断', () {
      expect(normalizeNickname('  阿明  '), '阿明');
      expect(normalizeNickname('   '), isNull);
      expect(
        normalizeNickname('a' * (nicknameMaxLength + 5)),
        'a' * nicknameMaxLength,
      );
    });
  });
}
