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
