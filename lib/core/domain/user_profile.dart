/// 用户资料纯函数（无副作用，可测）
///
/// 移植自 EVTool 小程序 src/lib/userProfile.js。
/// 供 profile 服务（storage 读写）与页面共用：
///   - [normalizeNickname]：昵称规整（去空白 + 截断），非法返回 null
///   - [mergeProfile]：不可变合并，只接受已知字段
library;

/// 昵称最大长度（字符数）
const int nicknameMaxLength = 20;

/// 用户资料默认值（页面层用 nickname 空串兜底显示「电车用户」）
const UserProfile defaultProfile = UserProfile(avatarUrl: '', nickname: '');

/// 用户资料（avatarUrl / nickname 两个已知字段）
class UserProfile {
  const UserProfile({this.avatarUrl = '', this.nickname});

  /// 头像地址（wxfile:// 本地路径或网络地址）
  final String avatarUrl;

  /// 昵称（可为 null：patch 显式传 null 时保留 null）
  final String? nickname;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'avatarUrl': avatarUrl,
    'nickname': nickname,
  };

  @override
  bool operator ==(Object other) {
    return other is UserProfile &&
        other.avatarUrl == avatarUrl &&
        other.nickname == nickname;
  }

  @override
  int get hashCode => Object.hash(avatarUrl, nickname);
}

/// 「字段未提供」哨兵（对应 JS undefined，区分显式传 null）
class _Unset {
  const _Unset();
}

const _Unset _unset = _Unset();

/// 待合并的用户资料 patch（只认识 avatarUrl / nickname）
class ProfilePatch {
  const ProfilePatch({this.avatarUrl, Object? nickname = _unset})
    : _nickname = nickname;

  /// 头像地址（仅接受 String，其他类型忽略并回落 base）
  final Object? avatarUrl;

  /// 昵称原始值（可能为 _unset / String / null）
  final Object? _nickname;

  /// 昵称字段是否被显式提供（对应 JS `source.nickname === undefined` 判断）
  bool get hasNickname => !identical(_nickname, _unset);

  /// 昵称字段值（仅 [hasNickname] 为 true 时有意义）
  String? get nicknameValue => _nickname as String?;
}

/// 规整昵称：去首尾空白、超长截断
///
/// 入参非字符串或空白返回 null。
String? normalizeNickname(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed.length <= nicknameMaxLength
      ? trimmed
      : trimmed.substring(0, nicknameMaxLength);
}

/// 不可变合并用户资料（只保留 avatarUrl / nickname 两个已知字段）
///
/// 非法 profile 按默认值兜底；avatarUrl 仅接受 String，
/// nickname 显式传 null 时保留 null（区分「未提供」）。
UserProfile mergeProfile(UserProfile? profile, ProfilePatch? patch) {
  final base = profile ?? defaultProfile;
  final source = patch ?? const ProfilePatch();
  return UserProfile(
    avatarUrl: source.avatarUrl is String
        ? source.avatarUrl as String
        : base.avatarUrl,
    nickname: source.hasNickname ? source.nicknameValue : base.nickname,
  );
}
