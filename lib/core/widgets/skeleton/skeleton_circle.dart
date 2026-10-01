import 'package:flutter/material.dart';

/// 圆形骨架屏占位基元。
///
/// 用于图标、头像等圆形内容。
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF20272C) : Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
