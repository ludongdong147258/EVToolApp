import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main.dart'),
);

class LocalStorage {
  LocalStorage(this._prefs, {FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  // --- Theme ---

  static const _themeKey = 'app_theme';

  ThemeMode get themeMode {
    final stored = _prefs.getString(_themeKey);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    return _prefs.setString(_themeKey, value);
  }

  // --- Auth ---
  //
  // Tokens are persisted in platform-secure storage (iOS Keychain). They are
  // mirrored into an in-memory cache so the synchronous Dio auth interceptor
  // can read the current token without an `await`. The cache is populated
  // once at startup via [initSecureAuth].

  static const _authTokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';

  String? _authToken;
  String? _refreshToken;

  /// Loads auth tokens from secure storage into the in-memory cache.
  ///
  /// Also performs a one-time migration of any tokens still stored in
  /// plaintext SharedPreferences (from before the secure-storage migration):
  /// moves them into secure storage and removes the plaintext copies.
  Future<void> initSecureAuth() async {
    _authToken = await _secureStorage.read(key: _authTokenKey);
    _refreshToken = await _secureStorage.read(key: _refreshTokenKey);

    final legacyAccess = _prefs.getString(_authTokenKey);
    final legacyRefresh = _prefs.getString(_refreshTokenKey);
    if (legacyAccess == null && legacyRefresh == null) return;

    _authToken ??= legacyAccess;
    _refreshToken ??= legacyRefresh;
    await _prefs.remove(_authTokenKey);
    await _prefs.remove(_refreshTokenKey);
    if (_authToken != null) {
      await _secureStorage.write(key: _authTokenKey, value: _authToken);
    }
    if (_refreshToken != null) {
      await _secureStorage.write(key: _refreshTokenKey, value: _refreshToken);
    }
  }

  String? get authToken => _authToken;
  Future<void> setAuthToken(String token) async {
    _authToken = token;
    await _secureStorage.write(key: _authTokenKey, value: token);
  }

  Future<void> removeAuthToken() async {
    _authToken = null;
    await _secureStorage.delete(key: _authTokenKey);
  }

  String? get refreshToken => _refreshToken;
  Future<void> setRefreshToken(String token) async {
    _refreshToken = token;
    await _secureStorage.write(key: _refreshTokenKey, value: token);
  }

  Future<void> removeRefreshToken() async {
    _refreshToken = null;
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  /// Clear all auth-related and user-bound data on logout.
  Future<void> clearAuthData() async {
    await Future.wait([removeAuthToken(), removeRefreshToken()]);
  }
}

final localStorageProvider = Provider<LocalStorage>(
  (ref) => LocalStorage(ref.watch(sharedPreferencesProvider)),
);
