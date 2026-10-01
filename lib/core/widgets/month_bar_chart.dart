import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/extensions/context_extensions.dart';

/// 12 个月柱状图的一根柱子。
@immutable
class MonthBar {
  const MonthBar({
    required this.month,
    required this.valueLabel,
    required this.percent,
    this.hasData = true,
  });

  /// 月份序号 1-12（展示用）。
  final int month;

  /// 柱顶数值标签（已格式化字符串）。
  final String valueLabel;

  /// 高度百分比 0-100（由 domain calcBarPercents 计算，含 4% 最小钳制）。
  final int percent;

  /// 是否有数据（无数据月份柱子用占位色）。
  final bool hasData;
}

/// 手写 12 月柱状图（移植小程序 .cr-chart / .ar-chart，不引第三方图表库）。
class MonthBarChart extends StatelessWidget {
  const MonthBarChart({super.key, required this.bars, this.height = 130});

  final List<MonthBar> bars;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < bars.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _BarColumn(bar: bars[i], color: palette.primary),
            ),
          ],
        ],
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({required this.bar, required this.color});

  final MonthBar bar;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasBar = bar.hasData && bar.percent > 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (hasBar)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              bar.valueLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: palette.textSecondary),
            ),
          ),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: hasBar
                ? FractionallySizedBox(
                    heightFactor: (bar.percent / 100).clamp(0.0, 1.0),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 16),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                  )
                : Container(
                    width: double.infinity,
                    height: 3,
                    constraints: const BoxConstraints(maxWidth: 16),
                    decoration: BoxDecoration(
                      color: palette.surfaceVariant,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(2),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${bar.month}',
          style: TextStyle(fontSize: 10, color: palette.textHint),
        ),
      ],
    );
  }
}
