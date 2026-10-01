import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// 统一 Shimmer 动画包装器。
///
/// 根据亮/暗主题自动切换 base/highlight 颜色，
/// 所有骨架屏共用此组件以确保视觉一致性。
class AppShimmerWrapper extends StatelessWidget {
  const AppShimmerWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF262D33) : const Color(0xFFE9EEF0),
      highlightColor: isDark
          ? const Color(0xFF343C42)
          : const Color(0xFFF5F5F5),
      direction: ShimmerDirection.ltr,
      period: const Duration(milliseconds: 1500),
      child: child,
    );
  }
}
