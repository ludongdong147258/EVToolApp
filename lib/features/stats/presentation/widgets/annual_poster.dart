import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/domain/poster.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/theme/app_palette.dart';

/// 海报绘制用的固定浅色色板（白底海报恒用浅色板，不随 App 深浅色切换；
/// 色值对应小程序 SharePoster 的 Canvas 常量）。
abstract final class _PosterPalette {
  static const EvPalette light = EvPalette.lightFallback;

  /// 次要说明文字（38% 黑）
  static const Color hint = Color(0x61000000);

  /// 占比条底槽 / 分隔线（6% 黑）
  static const Color track = Color(0x0F000000);

  /// 空月份灰柱
  static const Color barEmpty = Color(0xFFE0E0E0);

  /// 家充占比（琥珀，与页面占比条/图例一致）
  static const Color home = AppColors.amber;
}

/// 12 月柱区最小柱高（设计 px），与小程序 BAR_MIN_PX 一致。
const int _posterMinBarPx = 16;

/// 年度报告分享海报（普通 widget 树渲染，替代小程序 weapp Canvas）。
///
/// 按设计稿 750×1570 布局常量（[posterLayout]）排版，展示时由外层
/// FittedBox 缩放到屏宽，导出时经外层 RepaintBoundary.toImage 截图。
class AnnualPoster extends StatelessWidget {
  const AnnualPoster({super.key, required this.model});

  final PosterModel model;

  double get _contentWidth =>
      (posterLayout.width - posterLayout.padding * 2).toDouble();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: posterLayout.width.toDouble(),
      height: posterLayout.height.toDouble(),
      color: Colors.white,
      child: Stack(
        children: [
          _buildHero(),
          _buildSplit(),
          _buildBarChart(),
          _buildBest(),
          _buildFooter(),
        ],
      ),
    );
  }

  Positioned _section({required int top, required List<Widget> children}) {
    return Positioned(
      left: posterLayout.padding.toDouble(),
      top: top.toDouble(),
      width: _contentWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  /* 渐变 Hero 区：标题 + 年度充电支出 + 主数字 + 三列指标 */
  Widget _buildHero() {
    return Positioned(
      left: posterLayout.padding.toDouble(),
      top: posterLayout.heroTop.toDouble(),
      width: _contentWidth,
      height: posterLayout.heroHeight.toDouble(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(40, 52, 40, 40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _PosterPalette.light.heroGradient,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              model.titleText,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Color(0xD9FFFFFF), // 85% 白
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '年度充电支出',
              style: TextStyle(
                fontSize: 24,
                color: Color(0xBFFFFFFF), // 75% 白
              ),
            ),
            const SizedBox(height: 10),
            Text(
              model.heroCostText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            // 对齐 canvas 版 statTop：指标行紧跟主数字（底部留渐变空白），
            // 不再 Spacer 钉底（会造成 ~150 大间隙）
            const SizedBox(height: 56),
            IntrinsicHeight(
              child: Row(
                children: [
                  for (var i = 0; i < model.statLines.length; i++) ...[
                    if (i > 0)
                      const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: Color(0x4DFFFFFF), // 30% 白
                        indent: 4,
                        endIndent: 4,
                      ),
                    Expanded(child: _HeroStat(line: model.statLines[i])),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* 充电方式占比：底槽 + 快充/家充双色填充 + 左右图例 */
  Widget _buildSplit() {
    return _section(
      top: posterLayout.splitTop,
      children: [
        const Text(
          '充电方式',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 26),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 20,
            color: _PosterPalette.track,
            child: Row(
              // stretch：色块填满条高（同 annual_report_page 占比条）
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (model.fastPercent > 0)
                  Expanded(
                    flex: model.fastPercent,
                    child: ColoredBox(color: _PosterPalette.light.primary),
                  ),
                if (model.homePercent > 0)
                  Expanded(
                    flex: model.homePercent,
                    child: const ColoredBox(color: _PosterPalette.home),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Text(
              '快充 ${model.fastPercent}%',
              style: TextStyle(
                fontSize: 24,
                color: _PosterPalette.light.primary,
              ),
            ),
            const Spacer(),
            Text(
              '家充 ${model.homePercent}%',
              style: const TextStyle(fontSize: 24, color: Color(0xFF666666)),
            ),
          ],
        ),
      ],
    );
  }

  /* 12 月柱状图：标题 + 柱顶数值 + 全月刻度 */
  Widget _buildBarChart() {
    final heights = calcPosterBarHeights(
      model.barItems,
      posterLayout.barChartHeight,
      _posterMinBarPx,
    );
    return _section(
      top: posterLayout.barChartTop,
      children: [
        const Row(
          children: [
            Text(
              '月度费用',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w500,
                color: Color(0xFF666666),
              ),
            ),
            Spacer(),
            Text(
              '单位：元',
              style: TextStyle(fontSize: 20, color: _PosterPalette.hint),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: (posterLayout.barChartHeight + 34).toDouble(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < heights.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: _PosterBar(
                    item: model.barItems[i],
                    height: heights[i],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < heights.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 20,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /* 年度之最：左标签 + 右数值强调 + 下方说明，条目间细分隔线 */
  Widget _buildBest() {
    final items = model.bestItems.take(3).toList(growable: false);
    return _section(
      top: posterLayout.bestTop,
      children: [
        const Text(
          '年度之最',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) ...[
            Container(height: 1, color: _PosterPalette.track),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: posterLayout.bestItemHeight.toDouble(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        items[i].label,
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.2,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                    Text(
                      items[i].value,
                      style: TextStyle(
                        fontSize: 30,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: _PosterPalette.light.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  items[i].sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.2,
                    color: _PosterPalette.hint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /* 底部：分隔线 + 徽标 slogan + 产品名落款 */
  Widget _buildFooter() {
    return Positioned(
      left: posterLayout.padding.toDouble(),
      right: posterLayout.padding.toDouble(),
      top: (posterLayout.footerTop - 36).toDouble(),
      child: Column(
        children: [
          Container(height: 1, color: _PosterPalette.track),
          const SizedBox(height: 24),
          Text(
            model.sloganText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: _PosterPalette.light.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.line});

  final PosterStatLine line;

  @override
  Widget build(BuildContext context) {
    // 标签 / 数值 / 单位三行纵排（与应用内 hero 卡同口径）
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line.label,
          style: const TextStyle(fontSize: 24, color: Color(0xD9FFFFFF)),
        ),
        const SizedBox(height: 8),
        Text(
          line.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          line.unit,
          style: const TextStyle(fontSize: 20, color: Color(0xD9FFFFFF)),
        ),
      ],
    );
  }
}

/// 海报 12 月柱（空月份灰柱，有数据月份渐变主色 + 柱顶数值）。
class _PosterBar extends StatelessWidget {
  const _PosterBar({required this.item, required this.height});

  final PosterBar item;

  /// 归一化柱高（设计 px；0 = 空月份画最小灰柱）。
  final int height;

  @override
  Widget build(BuildContext context) {
    final hasBar = height > 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (hasBar) ...[
          Text(
            jsRound(item.value).toInt().toString(),
            style: const TextStyle(fontSize: 18, color: Color(0xFF666666)),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          width: double.infinity,
          height: hasBar ? height.toDouble() : _posterMinBarPx.toDouble(),
          decoration: BoxDecoration(
            color: hasBar
                ? _PosterPalette.light.primary
                : _PosterPalette.barEmpty,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
      ],
    );
  }
}
