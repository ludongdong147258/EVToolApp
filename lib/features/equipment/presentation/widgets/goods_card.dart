import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/skeleton/app_shimmer_wrapper.dart';
import 'package:ev_tool_app/core/widgets/skeleton/skeleton_box.dart';
import 'package:ev_tool_app/core/widgets/skeleton/skeleton_line.dart';
import 'package:ev_tool_app/features/equipment/data/goods_repository.dart';

/// 卡片图块估算高度（正方形图 ≈ 列宽 171，瀑布流估高用）。
const double goodsCardImageHeight = 171;

/// 双列商品瀑布流卡片（样式对齐小程序 eq-card：
/// 方图 / 两行标题 / 券 pill 行内 / 橙色价格 / 原价划线 / 销量）。
class GoodsCard extends StatelessWidget {
  const GoodsCard({super.key, required this.item, this.onTap});

  final GoodsItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.surfaceCard,
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      clipBehavior: Clip.antiAlias,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImage(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: palette.onSurface,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _PriceRow(item: item),
                  const SizedBox(height: 4),
                  if (item.salesTip.isNotEmpty)
                    Text(
                      item.salesTip,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final palette = context.palette;
    return AspectRatio(
      aspectRatio: 1,
      child: Image.network(
        item.thumbUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => ColoredBox(
          color: palette.surfaceContainer,
          child: Icon(Icons.image_outlined, size: 32, color: palette.textHint),
        ),
      ),
    );
  }
}

/// 券 pill（对齐小程序 .eq-coupon：奶油底 + 橙描边，置于价格行行首）。
class _CouponPill extends StatelessWidget {
  const _CouponPill({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: AppColors.goodsCouponBg,
        border: Border.all(color: AppColors.goodsCoupon),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Text(
        '\$${formatPrice(amount)} coupon',
        style: const TextStyle(
          fontSize: 10,
          height: 1,
          color: AppColors.goodsCoupon,
        ),
      ),
    );
  }
}

/// 价格行（对齐小程序 .eq-price-row，baseline 对齐）：
/// 券 pill + ¥ + 券后价 + 原价划线（始终显示）。
class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.item});

  final GoodsItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      runSpacing: 2,
      children: [
        if (item.hasCoupon) _CouponPill(amount: item.couponAmount),
        const Text(
          '\$',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.goodsPrice,
          ),
        ),
        Text(
          formatPrice(item.couponPrice),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1,
            color: AppColors.goodsPrice,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            '\$${formatPrice(item.originalPrice)}',
            style: TextStyle(
              fontSize: 12,
              color: palette.textSecondary,
              decoration: TextDecoration.lineThrough,
              decorationColor: palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 骨架屏卡（结构同 [GoodsCard]：图块 + 文字行 + 价格行）。
class GoodsSkeletonCard extends StatelessWidget {
  const GoodsSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShimmerWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonBox(height: goodsCardImageHeight, borderRadius: 0),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(width: double.infinity),
                SizedBox(height: 6),
                SkeletonLine(width: 96),
                SizedBox(height: 8),
                SkeletonBox(width: 64, height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
