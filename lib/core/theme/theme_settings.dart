import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/theme_colors.dart';
import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';

/// 主题设置：深浅色模式 + 品牌 accent。
///
/// 对应小程序 themeService（存储 key `themePreference`）+ 原主题模式持久化
/// （LocalStorage `app_theme`）。换肤通过 Riverpod 重建 MaterialApp 实现，
/// 替代小程序的 accentChange 事件广播。
@immutable
class ThemeSettings {
  const ThemeSettings({required this.mode, required this.accentId});

  final ThemeMode mode;
  final String accentId;

  AccentTheme get accent => getAccentById(accentId);
}

class ThemeSettingsNotifier extends Notifier<ThemeSettings> {
  static const String _accentKey = 'themePreference';

  @override
  ThemeSettings build() {
    final kv = ref.watch(keyValueStoreProvider);
    final localStorage = ref.watch(localStorageProvider);
    final accentId =
        normalizeAccentId(kv.getString(_accentKey)) ?? defaultAccentId;
    return ThemeSettings(mode: localStorage.themeMode, accentId: accentId);
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == state.mode) return;
    state = ThemeSettings(mode: mode, accentId: state.accentId);
    await ref.read(localStorageProvider).setThemeMode(mode);
  }

  Future<void> setAccentId(String accentId) async {
    final normalized = normalizeAccentId(accentId);
    if (normalized == null || normalized == state.accentId) return;
    state = ThemeSettings(mode: state.mode, accentId: normalized);
    await ref.read(keyValueStoreProvider).setString(_accentKey, normalized);
  }
}

final themeSettingsProvider =
    NotifierProvider<ThemeSettingsNotifier, ThemeSettings>(
      ThemeSettingsNotifier.new,
    );
