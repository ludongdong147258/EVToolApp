import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ev_tool_app/core/domain/user_profile.dart';
import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/features/vehicles/data/photo_store.dart';

/// 资料持久化异常（中文消息供页面 toast）。
class ProfileStorageException implements Exception {
  const ProfileStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 头像文件存储：`<appDocs>/avatars`（avatarUrl 只保存裸文件名）。
final avatarPhotoStoreProvider = FutureProvider<PhotoStore>((ref) async {
  final docs = await getApplicationDocumentsDirectory();
  return PhotoStore(Directory('${docs.path}/avatars'));
});

/// 用户资料仓储（移植小程序 userService.js）。
///
/// 存储key `userProfile`，结构 `{avatarUrl, nickname}`：
/// 头像经 [avatarPhotoStoreProvider] 落盘后以裸文件名入库，
/// 旧头像文件在换头像时尽力清理。
class UserProfileRepository {
  UserProfileRepository(this._kv, Future<PhotoStore> avatarStore)
    : _avatarStore = avatarStore;

  static const String storageKey = 'userProfile';

  final KeyValueStore _kv;
  final Future<PhotoStore> _avatarStore;

  /// 读取用户资料；缺失/脏数据返回默认值。
  UserProfile getProfile() {
    final raw = _kv.getJsonMap(storageKey);
    if (raw == null) {
      return defaultProfile;
    }
    return UserProfile(
      avatarUrl: raw['avatarUrl'] is String ? raw['avatarUrl'] as String : '',
      nickname: raw['nickname'] is String ? raw['nickname'] as String : null,
    );
  }

  /// 合并保存（不可变更新后写回，未传字段保留原值）。
  Future<UserProfile> saveProfile(ProfilePatch patch) async {
    final next = mergeProfile(getProfile(), patch);
    try {
      await _kv.setJson(storageKey, next.toJson());
    } on Exception catch (e) {
      appLogger.e('保存用户资料失败', error: e);
      throw const ProfileStorageException('保存失败');
    }
    return next;
  }

  /// 保存头像：临时文件转 `avatars/` 持久文件后入库，并清理旧头像文件。
  ///
  /// 抛 [ProfileStorageException]（路径无效/落盘失败）供页面 toast。
  Future<UserProfile> saveAvatar(String sourcePath) async {
    if (sourcePath.trim().isEmpty) {
      throw const ProfileStorageException('头像路径无效');
    }
    final store = await _avatarStore;
    final prevAvatarUrl = getProfile().avatarUrl;
    final String filename;
    try {
      filename = await store.save(sourcePath: sourcePath, key: 'avatar');
    } on PhotoStoreException {
      rethrow;
    } on Exception catch (e) {
      appLogger.e('保存头像文件失败', error: e);
      throw const ProfileStorageException('头像保存失败');
    }
    final next = await saveProfile(ProfilePatch(avatarUrl: filename));
    // 清理被替换的旧头像（尽力而为，失败不阻塞主流程）
    if (prevAvatarUrl.isNotEmpty && prevAvatarUrl != filename) {
      await store.delete(prevAvatarUrl);
    }
    return next;
  }
}

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(
    ref.watch(keyValueStoreProvider),
    ref.watch(avatarPhotoStoreProvider.future),
  );
});

/// 用户资料状态：存储即真相，保存后回读刷新。
class UserProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() => ref.watch(userProfileRepositoryProvider).getProfile();

  UserProfileRepository get _repo => ref.read(userProfileRepositoryProvider);

  /// 保存昵称（清空视为恢复默认昵称，页面兜底显示「电车用户」）。
  Future<void> saveNickname(String raw) async {
    final normalized = normalizeNickname(raw) ?? '';
    state = await _repo.saveProfile(ProfilePatch(nickname: normalized));
  }

  /// 保存头像（临时文件转持久文件后入库）。
  Future<void> saveAvatar(String sourcePath) async {
    state = await _repo.saveAvatar(sourcePath);
  }
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);
