import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// share_plus 统一分享入口。
///
/// iPad 上系统分享面板是 popover，share_plus 要求提供非零的
/// `sharePositionOrigin`（锚点矩形），否则抛 PlatformException。
/// 此处取调用方 [context] 对应 RenderBox 的屏幕矩形，取不到或为零时
/// 回退整屏矩形。
Future<ShareResult> shareFiles(BuildContext context, List<XFile> files) async {
  final renderObject = context.findRenderObject();
  final screenSize = MediaQuery.sizeOf(context);
  final Rect origin =
      renderObject is RenderBox &&
          renderObject.attached &&
          renderObject.size != Size.zero
      ? renderObject.localToGlobal(Offset.zero) & renderObject.size
      : Offset.zero & screenSize;
  return Share.shareXFiles(files, sharePositionOrigin: origin);
}
