import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ev_tool_app/core/routing/access_guard.dart';
import 'package:ev_tool_app/core/routing/route_names.dart';
import 'package:ev_tool_app/core/widgets/app_error_widget.dart';
import 'package:ev_tool_app/core/widgets/main_shell.dart';
import 'package:ev_tool_app/features/auth/presentation/auth_state.dart';
import 'package:ev_tool_app/features/auth/presentation/pages/login_page.dart';
import 'package:ev_tool_app/features/charging/presentation/pages/charging_page.dart';
import 'package:ev_tool_app/features/home/presentation/pages/home_page.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/about_page.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/profile_page.dart';
import 'package:ev_tool_app/features/profile/presentation/pages/settings_page.dart';
import 'package:ev_tool_app/features/tools/presentation/pages/tools_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Validate that a redirect target is a known internal route.
bool _isValidRoute(String path) {
  const validRoutes = <String>{
    RouteNames.home,
    RouteNames.charging,
    RouteNames.tools,
    RouteNames.profile,
    RouteNames.login,
    RouteNames.settings,
    RouteNames.about,
  };
  return validRoutes.contains(path);
}

/// Bridges Riverpod provider changes into GoRouter's ChangeNotifier world:
/// any auth state change re-runs the router redirect.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(this._ref) {
    _authSubscription = _ref.listen<AuthState>(
      authNotifierProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _authSubscription;

  @override
  void dispose() {
    _authSubscription.close();
    super.dispose();
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouteNames.home,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: GoRouterRefreshStream(ref),
    redirect: (context, state) {
      // 在 redirect 回调内读取 auth 状态，避免 GoRouter 因 ref.watch 被重建
      final isAuthenticated =
          ref.read(authNotifierProvider) is AuthAuthenticated;
      final isLoginRoute = state.matchedLocation == RouteNames.login;

      // 已登录用户访问登录页时跳转到原始目标页面或首页
      if (isAuthenticated && isLoginRoute) {
        final from = state.uri.queryParameters['from'];
        if (from != null && from.isNotEmpty && _isValidRoute(from)) {
          return from;
        }
        return RouteNames.home;
      }

      // 受保护路由（我的）：校验登录态，未登录跳登录页并保留目标位置。
      return resolveProtectedAccess(
        location: state.matchedLocation,
        isAuthenticated: isAuthenticated,
      );
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(shell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.home,
                name: 'home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.charging,
                name: 'charging',
                builder: (context, state) => const ChargingPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.tools,
                name: 'tools',
                builder: (context, state) => const ToolsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.profile,
                name: 'profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: RouteNames.settings,
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: RouteNames.about,
        name: 'about',
        builder: (context, state) => const AboutPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: AppErrorWidget(
        message: 'Page not found: ${state.error}',
        onRetry: () => context.go(RouteNames.home),
      ),
    ),
  );
});
