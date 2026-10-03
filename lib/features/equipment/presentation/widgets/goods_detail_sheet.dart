import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ev_tool_app/core/domain/numbers.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart';
import 'package:ev_tool_app/core/utils/logger.dart';
import 'package:ev_tool_app/features/equipment/data/goods_repository.dart';

/// 商品详情弹层：大图 + 标题 + 价格 + 优惠券 + 前往拼多多购买。
///
/// iOS 端无微信 weapp 链路，购买统一走推广短链外链打开；
/// 打不开时降级复制链接 + toast。
class GoodsDetailSheet extends StatelessWidget {
  const GoodsDetailSheet({super.key, required this.item});

  final GoodsItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppSheetScrollBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            child: SizedBox(
              height: 220,
              child: Image.network(
                item.thumbUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: palette.surfaceContainer,
                  child: Icon(
                    Icons.image_outlined,
                    size: 40,
                    color: palette.textHint,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: context.textTheme.titleSmall?.copyWith(
              color: palette.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '\$',
                style: context.textTheme.titleMedium?.copyWith(
                  color: AppColors.goodsPrice,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                formatPrice(item.couponPrice),
                style: context.textTheme.headlineMedium?.copyWith(
                  color: AppColors.goodsPrice,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (item.hasCoupon) ...[
                const SizedBox(width: 6),
                Text(
                  '\$${formatPrice(item.originalPrice)}',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: palette.textHint,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: palette.textHint,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Coupon saves \$${formatPrice(item.couponAmount)}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: palette.onErrorContainer,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (item.salesTip.isNotEmpty)
            Text(
              item.salesTip,
              style: context.textTheme.bodySmall?.copyWith(
                color: palette.textHint,
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => unawaited(_buy(context)),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
              ),
            ),
            child: const Text('Buy on Pinduoduo'),
          ),
        ],
      ),
    );
  }

  Future<void> _buy(BuildContext context) async {
    final url = item.shortUrl;
    if (url.isEmpty) {
      showAppToast(
        context,
        'Product link is being generated — try again shortly',
      );
      return;
    }
    final uri = Uri.tryParse(url);
    var canLaunch = false;
    if (uri != null) {
      try {
        canLaunch = await canLaunchUrl(uri);
      } on Exception catch (e) {
        appLogger.w('Failed to check purchase link: $e');
      }
    }
    if (uri != null && canLaunch) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      } on Exception catch (e) {
        appLogger.w('Failed to open purchase link: $e');
      }
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      showAppToast(context, 'Link copied — open it in your browser');
    }
  }
}

/// 便捷入口：弹出商品详情弹层。
Future<void> showGoodsDetailSheet(BuildContext context, GoodsItem item) {
  return showAppSheet(
    context: context,
    title: 'Product details',
    builder: (sheetContext) => GoodsDetailSheet(item: item),
  );
}
