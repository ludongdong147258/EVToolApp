import 'dart:async';

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

  void insert() {
    if (!overlay.mounted) return;
    overlay.insert(entry);
    Future.delayed(duration, () {
      // mounted 守卫：toast 已被移除或宿主销毁时不重复 remove
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  // 路由退出转场进行中（如弹层保存后 pop + toast）时，等转场结束再插入：
  // iOS 26 模拟器 Impeller 在转场中插入 overlay 会残留上一帧画面
  // （表现为 toast 下方出现弹窗/页面内容的叠影，直到下次重绘才消失）。
  final route = ModalRoute.of(context);
  final animation = route?.animation;
  if (route != null &&
      animation != null &&
      animation.status == AnimationStatus.reverse) {
    unawaited(_whenDismissed(animation).then((_) => insert()));
    return;
  }
  insert();
}

/// 等待路由转场动画回到 [AnimationStatus.dismissed]（退出转场完成）。
///
/// 带超时兜底：若转场被取消（如 pop 中断），超时后仍插入 toast，
/// 保证提示不会丢失。
Future<void> _whenDismissed(Animation<double> animation) {
  if (animation.status == AnimationStatus.dismissed) {
    return Future<void>.value();
  }
  final completer = Completer<void>();
  void listener(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      animation.removeStatusListener(listener);
      if (!completer.isCompleted) completer.complete();
    }
  }

  animation.addStatusListener(listener);
  return completer.future.timeout(
    const Duration(milliseconds: 800),
    onTimeout: () {
      animation.removeStatusListener(listener);
      if (!completer.isCompleted) completer.complete();
    },
  );
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
          // Material 提供 DefaultTextStyle：rootOverlay 的 entry 没有 Material 祖先，
          // 否则 Text 会命中 MaterialApp 的 _errorTextStyle fallback，
          // 继承到黄色双下划线 decoration（表现为"已保存"下方两条横线）。
          child: Material(
            type: MaterialType.transparency,
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
