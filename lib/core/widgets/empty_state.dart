import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';

/// 统一空态占位（移植小程序 EmptyState）：图标 + 标题 + 副文案 + 可选 CTA。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.ctaText,
    this.onCta,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? ctaText;
  final VoidCallback? onCta;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 24 : 48,
        horizontal: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: palette.textHint),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium?.copyWith(
              color: palette.onSurfaceVariant,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall?.copyWith(
                color: palette.textHint,
              ),
            ),
          ],
          if (ctaText != null && onCta != null) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onCta,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusLg),
                ),
              ),
              child: Text(ctaText!),
            ),
          ],
        ],
      ),
    );
  }
}
