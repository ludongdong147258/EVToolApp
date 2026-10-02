import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/theme/app_colors.dart';

/// 堆叠占比条的一个分段。
@immutable
class StackedSegment {
  const StackedSegment({required this.colorKey, required this.percent});

  /// 支出类型 key（charge/insurance/...），经 [AppColors.costTypeColor] 取色。
  final String colorKey;
  final int percent;
}

/// 水平堆叠占比条（移植小程序 .cr-split-bar / .ar-split-bar）。
class StackedBar extends StatelessWidget {
  const StackedBar({super.key, required this.segments, this.height = 10});

  final List<StackedSegment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clipped = segments.where((s) => s.percent > 0).toList();
    if (clipped.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(
          // stretch：色块填满条高（ColoredBox 无 child 在宽松高度约束下
          // 会塌缩为 0 高，占比条会一直只剩占位空条）
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final segment in clipped)
              Expanded(
                flex: segment.percent,
                child: ColoredBox(
                  color: AppColors.costTypeColor(segment.colorKey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
