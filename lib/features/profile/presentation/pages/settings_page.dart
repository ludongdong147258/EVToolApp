import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/domain/theme_colors.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/theme_settings.dart';
import 'package:ev_tool_app/features/profile/presentation/widgets/accent_swatch.dart';

/// 设置页：深浅色模式 + 品牌主题色。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader('外观'),
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
              trailing: mode == settings.mode ? const Icon(Icons.check) : null,
              onTap: () {
                ref.read(themeSettingsProvider.notifier).setMode(mode);
              },
            ),
          const Divider(height: 32, indent: 16, endIndent: 16),
          const _SectionHeader('主题配色'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final accent in accentThemes)
                  AccentSwatch(
                    accent: accent,
                    isSelected: accent.id == settings.accentId,
                    onTap: () => ref
                        .read(themeSettingsProvider.notifier)
                        .setAccentId(accent.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: context.textTheme.titleSmall?.copyWith(
          color: context.palette.textSecondary,
        ),
      ),
    );
  }
}
