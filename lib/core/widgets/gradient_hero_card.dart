import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';

/// 渐变 hero 卡（135° primary → primaryContainer，白字数据区）。
class GradientHeroCard extends StatelessWidget {
  const GradientHeroCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.heroGradient,
        ),
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        boxShadow: [
          BoxShadow(
            color: palette.primaryContainer.withValues(alpha: 0.3),
            offset: const Offset(0, 4),
            blurRadius: 14,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// hero 卡内三列统计（半透明分隔线），移植 .hero-stats。
class HeroStatsRow extends StatelessWidget {
  const HeroStatsRow({super.key, required this.items});

  final List<HeroStatItem> items;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.onPrimaryA28,
                indent: 4,
                endIndent: 4,
              ),
            Expanded(child: items[i]),
          ],
        ],
      ),
    );
  }
}

class HeroStatItem extends StatelessWidget {
  const HeroStatItem({
    super.key,
    required this.label,
    required this.value,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.onPrimaryA85),
        ),
        const SizedBox(height: 6),
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.onPrimaryA85,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// hero 卡主数值（如月度花费）。
class HeroValue extends StatelessWidget {
  const HeroValue({super.key, required this.value, this.unit});

  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          if (unit != null)
            TextSpan(
              text: '$unit ',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.onPrimaryA85,
              ),
            ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// hero 卡右上角圆形按钮（半透明白底）。
class HeroCircleButton extends StatelessWidget {
  const HeroCircleButton({super.key, required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.onPrimaryA22,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}
