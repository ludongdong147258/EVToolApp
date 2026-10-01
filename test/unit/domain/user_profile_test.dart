/// user_profile.dart 单测（移植自 src/lib/__tests__/userProfile.test.js）
library;

import 'package:ev_tool_app/core/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeNickname 昵称规整', () {
    test('去除首尾空白后返回字符串', () {
      expect(normalizeNickname('  电车用户 '), '电车用户');
    });

    test('超过最大长度时截断', () {
      final raw = 'a' * (nicknameMaxLength + 1);
      expect(normalizeNickname(raw), 'a' * nicknameMaxLength);
    });

    test('空白或非字符串输入返回 null', () {
      expect(normalizeNickname('   '), isNull);
      expect(normalizeNickname(''), isNull);
      expect(normalizeNickname(null), isNull);
      expect(normalizeNickname(123), isNull);
    });
  });

  group('mergeProfile 不可变合并', () {
    test('返回新对象且不修改入参', () {
      // Arrange
      const profile = UserProfile(avatarUrl: '', nickname: '旧昵称');
      const patch = ProfilePatch(nickname: '新昵称');

      // Act
      final result = mergeProfile(profile, patch);

      // Assert
      expect(result, const UserProfile(avatarUrl: '', nickname: '新昵称'));
      expect(profile.nickname, '旧昵称');
      expect(identical(result, profile), isFalse);
    });

    test('仅接受已知字段，未知字段被丢弃（显式 null 保留）', () {
      // Arrange
      const profile = UserProfile(avatarUrl: 'wxfile://a.png', nickname: '用户');

      // Act
      final result = mergeProfile(profile, const ProfilePatch(nickname: null));

      // Assert
      expect(result.avatarUrl, 'wxfile://a.png');
      expect(result.nickname, isNull);
      expect(result.toJson().containsKey('extra'), isFalse);
    });

    test('非法 profile 兜底为空对象再合并', () {
      final result = mergeProfile(
        null,
        ProfilePatch(nickname: normalizeNickname(' 用户 ')),
      );

      expect(result, const UserProfile(avatarUrl: '', nickname: '用户'));
    });

    test('avatarUrl 仅接受字符串，非字符串回落 base', () {
      const profile = UserProfile(avatarUrl: 'wxfile://a.png', nickname: '用户');
      final result = mergeProfile(profile, const ProfilePatch(avatarUrl: 123));
      expect(result.avatarUrl, 'wxfile://a.png');

      final updated = mergeProfile(
        profile,
        const ProfilePatch(avatarUrl: 'wxfile://b.png'),
      );
      expect(updated.avatarUrl, 'wxfile://b.png');
    });
  });
}
