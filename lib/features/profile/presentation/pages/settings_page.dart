import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/storage/local_storage.dart';

/// 设置页：演示主题切换（light/dark/system 持久化到 SharedPreferences）。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localStorage = ref.watch(localStorageProvider);
    final themeMode = localStorage.themeMode;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          for (final mode in ThemeMode.values)
            ListTile(
              leading: Icon(switch (mode) {
                ThemeMode.system => Icons.brightness_auto_outlined,
                ThemeMode.light => Icons.light_mode_outlined,
                ThemeMode.dark => Icons.dark_mode_outlined,
              }),
              title: Text(switch (mode) {
                ThemeMode.system => '跟随系统',
                ThemeMode.light => '浅色',
                ThemeMode.dark => '深色',
              }),
              trailing: mode == themeMode ? const Icon(Icons.check) : null,
              onTap: () {
                localStorage.setThemeMode(mode);
                ref.invalidate(localStorageProvider);
              },
            ),
        ],
      ),
    );
  }
}
