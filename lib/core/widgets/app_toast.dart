import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/theme/app_colors.dart';

/// Toast 统一走 Overlay 实现（不进 Navigator 栈）：
/// 页面在 toast 展示期间被 pop 也不会破坏 go_router 路由栈。
void _showOverlayToast(
  BuildContext context, {
  required String message,
  IconData? icon,
  Duration duration = const Duration(seconds: 2),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final entry = OverlayEntry(
    builder: (_) => _ToastView(message: message, icon: icon),
  );
  overlay.insert(entry);
  Future.delayed(duration, () {
    // mounted 守卫：toast 已被移除或宿主销毁时不重复 remove
    if (entry.mounted) {
      entry.remove();
    }
  });
}

class _ToastView extends StatelessWidget {
  const _ToastView({required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 居中成功提示，自动 2 秒消失。
void showSuccessToast(
  BuildContext context, {
  String message = 'Submitted successfully',
}) {
  _showOverlayToast(context, message: message, icon: Icons.check_circle);
}

/// 居中错误提示，自动 2 秒消失。
void showErrorToast(BuildContext context, String message) {
  _showOverlayToast(context, message: message, icon: Icons.error_outline);
}

/// 通用居中提示，对应小程序 Taro.showToast({icon:"none"})。
void showAppToast(BuildContext context, String message) {
  _showOverlayToast(context, message: message);
}
