import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/theme/app_colors.dart';

class AppTabSelector extends StatelessWidget {
  const AppTabSelector({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    this.onChanged,
    this.activeColor,
    this.activeTextColor,
    this.inactiveTextColor,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int>? onChanged;
  final Color? activeColor;
  final Color? activeTextColor;
  final Color? inactiveTextColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColor = colorScheme.surface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardDark.withValues(alpha: 0.5)
            : AppColors.glassWhite,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isActive = index == selectedIndex;
          return Expanded(
            child: Semantics(
              button: true,
              label: tabs[index],
              selected: isActive,
              child: GestureDetector(
                onTap: () => onChanged?.call(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? (activeColor ?? surfaceColor)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tabs[index],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? (activeTextColor ?? colorScheme.onSurface)
                          : (inactiveTextColor ?? colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
