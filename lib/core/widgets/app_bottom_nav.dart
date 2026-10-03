import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';

/// 浮动胶囊底部导航（移植小程序 BottomNav）。
///
/// 4 个 tab：充电记录 / 养车支出 / 实用工具 / 我的；
/// [showToolsDot] 为工具 tab 的备忘录到期红点。
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
    this.showToolsDot = false,
  });

  final int currentIndex;
  final ValueChanged<int>? onTap;
  final bool showToolsDot;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppColors.bottomNavOffset,
        0,
        AppColors.bottomNavOffset,
        AppColors.bottomNavOffset,
      ),
      height: AppColors.bottomNavHeight,
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, -4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          _NavItem(
            icon: Icons.ev_station_rounded,
            label: 'Records',
            isActive: currentIndex == 0,
            onTap: () => onTap?.call(0),
          ),
          _NavItem(
            icon: Icons.payments_rounded,
            label: 'Costs',
            isActive: currentIndex == 1,
            onTap: () => onTap?.call(1),
          ),
          _NavItem(
            icon: Icons.build_rounded,
            label: 'Tools',
            isActive: currentIndex == 2,
            showDot: showToolsDot,
            onTap: () => onTap?.call(2),
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            isActive: currentIndex == 3,
            onTap: () => onTap?.call(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.showDot = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final bool showDot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = isActive ? palette.primary : palette.textHint;

    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        selected: isActive,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 24, color: color),
                  if (showDot)
                    Positioned(
                      top: -1,
                      right: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: palette.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: palette.surfaceCard,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  decoration: TextDecoration.none,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
