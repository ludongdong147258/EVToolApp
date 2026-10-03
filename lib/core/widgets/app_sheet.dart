import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';

/// 底部弹层（移植小程序 BottomSheet 的调用模式）。
///
/// 遮罩 + 上滑动画 + 顶部 24 圆角 + 最高 75% 高度由 [AppTheme] 的
/// bottomSheetTheme 与 [showModalBottomSheet] 共同提供。
/// 关闭按钮 + 标题头与小程序一致。
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  bool showClose = true,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.75,
    ),
    builder: (context) => _AppSheetShell(
      title: title,
      showClose: showClose,
      child: builder(context),
    ),
  );
}

class _AppSheetShell extends StatelessWidget {
  const _AppSheetShell({
    required this.title,
    required this.showClose,
    required this.child,
  });

  final String title;
  final bool showClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题水平居中：Stack 让标题占满全宽居中，关闭按钮叠在右侧
            SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      title,
                      style: context.textTheme.headlineSmall?.copyWith(
                        color: palette.primaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (showClose)
                    Positioned(
                      right: 0,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close, size: 24),
                        color: palette.onSurfaceVariant,
                        tooltip: 'Close',
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

/// 弹层内容需要独立滚动时包裹此组件。
class AppSheetScrollBody extends StatelessWidget {
  const AppSheetScrollBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppColors.radiusLg),
        child: child,
      ),
    );
  }
}
