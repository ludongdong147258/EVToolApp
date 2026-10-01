import 'package:flutter/material.dart';

/// 矩形骨架屏占位基元。
///
/// 用于卡片区域、图表占位等矩形内容。
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 10,
  });

  final double? width;
  final double? height;
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
