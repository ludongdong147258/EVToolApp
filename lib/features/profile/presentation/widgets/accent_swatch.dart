import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/domain/theme_colors.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';

/// 主题色卡：渐变预览圆 + 名称；选中态描边打勾。
///
/// 设置页与「我的」页主题配色弹层共用。
class AccentSwatch extends StatelessWidget {
  const AccentSwatch({
    super.key,
    required this.accent,
    required this.isSelected,
    this.onTap,
  });

  final AccentTheme accent;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: accent.name,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(accent.primary),
                    Color(accent.primaryContainer),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? context.palette.onSurface
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              accent.name,
              style: TextStyle(
                fontSize: 12,
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
