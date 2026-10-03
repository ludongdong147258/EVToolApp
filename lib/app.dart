import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/constants/app_constants.dart';
import 'package:ev_tool_app/core/routing/app_router.dart';
import 'package:ev_tool_app/core/theme/app_theme.dart';
import 'package:ev_tool_app/core/theme/theme_settings.dart';

class EvToolApp extends ConsumerWidget {
  const EvToolApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final settings = ref.watch(themeSettingsProvider);
    final accent = settings.accent;

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      theme: AppTheme.light(accent),
      darkTheme: AppTheme.dark(accent),
      themeMode: settings.mode,
      routerConfig: router,
    );
  }
}
