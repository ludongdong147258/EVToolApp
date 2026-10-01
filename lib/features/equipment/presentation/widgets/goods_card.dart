import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/skeleton/app_shimmer_wrapper.dart';
import 'package:ev_tool_app/core/widgets/skeleton/skeleton_box.dart';
import 'package:ev_tool_app/core/widgets/skeleton/skeleton_line.dart';
import 'package:ev_tool_app/features/equipment/data/goods_repository.dart';

/// 卡片图块高度（瀑布流双列卡片统一图高，保证可估高）
const double goodsCardImageHeight = 150;

/// 双列商品瀑布流卡片（图 / 名 / 券后价 / 原价划线 / 券后标签 / 销量）。
///
/// 视觉对齐小程序 eq-card：橙色价格强调、券 pill、原价划线。
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
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImage(context),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: palette.onSurface,
                    ),
                  ),
                  if (item.hasCoupon) ...[
                    const SizedBox(height: 6),
                    _CouponPill(amount: item.couponAmount),
                  ],
                  const SizedBox(height: 6),
                  _PriceRow(item: item),
                  const SizedBox(height: 4),
                  Text(
                    item.salesTip,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: palette.textHint,
                      fontSize: 11,
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
    return SizedBox(
      height: goodsCardImageHeight,
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

class _CouponPill extends StatelessWidget {
  const _CouponPill({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: palette.errorContainer,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Text(
        '券${formatPrice(amount)}元',
        style: context.textTheme.bodySmall?.copyWith(
          color: palette.onErrorContainer,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.item});

  final GoodsItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '¥',
          style: context.textTheme.bodySmall?.copyWith(
            color: AppColors.fastCharge,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          formatPrice(item.couponPrice),
          style: context.textTheme.titleLarge?.copyWith(
            color: AppColors.fastCharge,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (item.hasCoupon) ...[
          const SizedBox(width: 4),
          Text(
            '¥${formatPrice(item.originalPrice)}',
            style: context.textTheme.bodySmall?.copyWith(
              color: palette.textHint,
              fontSize: 11,
              decoration: TextDecoration.lineThrough,
              decorationColor: palette.textHint,
            ),
          ),
        ],
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
            padding: EdgeInsets.all(10),
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
