import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ev_tool_app/core/constants/app_constants.dart';
import 'package:ev_tool_app/core/widgets/app_loading.dart';
import 'package:ev_tool_app/core/widgets/app_primary_button.dart';
import 'package:ev_tool_app/features/auth/presentation/auth_state.dart';

/// 占位登录页：触发 mock 登录，验证路由守卫与 auth 状态闭环。
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.ev_station_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                AppConstants.appName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Electric Vehicle Companion',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 48),
              switch (authState) {
                AuthLoading() => const Center(child: AppLoading()),
                AuthError(:final message) => Column(
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppPrimaryButton(
                      text: 'Retry',
                      onTap: () =>
                          ref.read(authNotifierProvider.notifier).login(),
                    ),
                  ],
                ),
                _ => AppPrimaryButton(
                  text: 'Sign In',
                  onTap: () => ref.read(authNotifierProvider.notifier).login(),
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}
