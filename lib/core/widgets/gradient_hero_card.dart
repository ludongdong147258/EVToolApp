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

/// hero 卡内三列统计（半透明分隔线，两侧留白），移植 .hero-stats。
class HeroStatsRow extends StatelessWidget {
  const HeroStatsRow({super.key, required this.items});

  final List<HeroStatItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: AppColors.onPrimaryA28,
            ),
          Expanded(child: items[i]),
        ],
      ],
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

  /// 数值字号按长度自适应（对齐小程序 stat-col-value 变体：
  /// ≤6 字 --lg 22 / ≤9 字默认 18 / 更长 --sm 14，防长数字溢出列宽）。
  static const int _largeValueMaxLength = 6;
  static const int _mediumValueMaxLength = 9;

  double get _valueFontSize {
    if (value.length <= _largeValueMaxLength) {
      return 22;
    }
    if (value.length <= _mediumValueMaxLength) {
      return 18;
    }
    return 14;
  }

  @override
  Widget build(BuildContext context) {
    // 标签 / 数值 / 单位三行纵排
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, color: AppColors.onPrimaryA85),
        ),
        const SizedBox(height: 4),
        // 数值放不下时整段等比缩小（如 4 列占比 "100%"），不出现省略号
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: _valueFontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        if (unit != null) ...[
          const SizedBox(height: 2),
          Text(
            unit!,
            style: const TextStyle(fontSize: 12, color: AppColors.onPrimaryA85),
          ),
        ],
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
    const valueStyle = TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      height: 1.2,
    );
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          // ¥ 等前缀与数值同段同尺寸（对齐小程序 .hero-value 单一文本）
          if (unit != null) TextSpan(text: unit, style: valueStyle),
          TextSpan(text: value, style: valueStyle),
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
