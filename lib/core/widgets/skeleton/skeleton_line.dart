import 'package:flutter/material.dart';

/// 文本行骨架屏占位基元。
///
/// 用于标题、标签、数值等文本内容占位。
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 4,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF20272C) : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
