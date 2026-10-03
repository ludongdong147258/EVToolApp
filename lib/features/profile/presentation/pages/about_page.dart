import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ev_tool_app/core/constants/app_constants.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/routing/route_names.dart';

/// 应用描述（移植小程序 about 页 APP_DESCRIPTION）。
const String _appDescription =
    'A practical companion app for electric vehicle owners, offering charging '
    'record management, charging statistics, fuel-versus-EV cost comparison, '
    'and time-of-use electricity pricing calculators to help you understand '
    'your true cost of driving.';

/// 关于页（子页）：品牌区 + 简介 + 信息列表。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = palette.accent;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          // 品牌区
          Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(accent.primary),
                      Color(accent.heroGradientEnd),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(
                        accent.primaryContainer,
                      ).withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.ev_station_rounded,
                  size: 36,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${AppConstants.appName} · EV Toolkit',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 简介
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _appDescription,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: palette.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 信息列表
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.menu_book_rounded,
                  text: 'User Agreement',
                  onTap: () => context.push(RouteNames.agreement),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: palette.divider,
                ),
                _InfoRow(
                  icon: Icons.lock_rounded,
                  text: 'Privacy Policy',
                  onTap: () => context.push(RouteNames.privacy),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: palette.divider,
                ),
                const _InfoRow(
                  icon: Icons.info_outline_rounded,
                  text: 'Version',
                  value: AppConstants.appVersion,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 信息列表行：图标 + 文案 + 值/箭头。
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
            if (value != null)
              Flexible(
                child: Text(
                  value!,
                  style: TextStyle(fontSize: 13, color: palette.textHint),
                ),
              ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: palette.textHint,
              ),
          ],
        ),
      ),
    );
  }
}
