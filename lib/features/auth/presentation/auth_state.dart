import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/storage/local_storage.dart';

// --- Auth State ---

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated();
}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}

// --- Auth Notifier ---

/// 最小认证骨架：login/logout 仅切换状态并写入/清除占位 token，
/// 不调用真实 API。接入后端后，将 [login] 替换为 AuthRepository 调用，
/// 并在成功后写入服务端下发的 accessToken/refreshToken。
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final localStorage = ref.read(localStorageProvider);
    final token = localStorage.authToken;
    if (token != null) {
      return const AuthAuthenticated();
    }
    return const AuthInitial();
  }

  Future<void> login() async {
    state = const AuthLoading();
    try {
      final localStorage = ref.read(localStorageProvider);
      // TODO(backend): 替换为真实登录 API，写入服务端 token。
      await localStorage.setAuthToken('mock-access-token');
      await localStorage.setRefreshToken('mock-refresh-token');
      state = const AuthAuthenticated();
    } on Exception catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> logout() async {
    await ref.read(localStorageProvider).clearAuthData();
    state = const AuthInitial();
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider) is AuthAuthenticated;
});
