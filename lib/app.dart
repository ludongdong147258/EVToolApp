import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/routing/app_router.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';
import 'package:ev_tool_app/core/theme/app_theme.dart';

class EvToolApp extends ConsumerStatefulWidget {
  const EvToolApp({super.key});

  @override
  ConsumerState<EvToolApp> createState() => _EvToolAppState();
}

class _EvToolAppState extends ConsumerState<EvToolApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final localStorage = ref.watch(localStorageProvider);
    final themeMode = localStorage.themeMode;

    return MaterialApp.router(
      title: 'EV Tool',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
