import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/domain/theme_colors.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';

/// 语义色板 ThemeExtension：品牌色由 [AccentTheme] 注入，中性色随深浅色切换。
///
/// 通过 `Theme.of(context).extension<EvPalette>()!` 读取。
@immutable
class EvPalette extends ThemeExtension<EvPalette> {
  const EvPalette({required this.brightness, required this.accent});

  /// 兜底色板（默认 green、浅色）；正常路径下由 AppTheme 注入，不会走到。
  static const EvPalette lightFallback = EvPalette(
    brightness: Brightness.light,
    accent: defaultAccentTheme,
  );

  final Brightness brightness;
  final AccentTheme accent;

  bool get isDark => brightness == Brightness.dark;

  // --- 品牌色 ---
  Color get primary => Color(accent.primary);
  Color get primaryContainer => Color(accent.primaryContainer);
  Color get secondary => Color(accent.secondary);
  Color get secondaryContainer =>
      Color(isDark ? accent.darkSecondaryContainer : accent.secondaryContainer);
  Color get onSecondaryContainer => Color(
    isDark ? accent.darkOnSecondaryContainer : accent.onSecondaryContainer,
  );

  /// hero 卡 135° 渐变。
  List<Color> get heroGradient => [
    Color(isDark ? accent.darkHeroGradientStart : accent.heroGradientStart),
    Color(isDark ? accent.darkHeroGradientEnd : accent.heroGradientEnd),
  ];

  // --- 中性色 ---
  Color get backgroundPale =>
      isDark ? AppColors.backgroundPaleDark : AppColors.backgroundPale;
  Color get surface => isDark ? AppColors.surfaceDark : AppColors.surface;
  Color get surfaceCard =>
      isDark ? AppColors.surfaceCardDark : AppColors.surfaceCard;
  Color get surfaceContainerLow => isDark
      ? AppColors.surfaceContainerLowDark
      : AppColors.surfaceContainerLow;
  Color get surfaceContainer =>
      isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainer;
  Color get surfaceContainerHighest => isDark
      ? AppColors.surfaceContainerHighestDark
      : AppColors.surfaceContainerHighest;
  Color get surfaceVariant =>
      isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant;
  Color get onSurface => isDark ? AppColors.onSurfaceDark : AppColors.onSurface;
  Color get onSurfaceVariant =>
      isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariant;
  Color get textSecondary =>
      isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
  Color get textHint => isDark ? AppColors.textHintDark : AppColors.textHint;
  Color get divider => isDark ? AppColors.dividerDark : AppColors.divider;
  Color get outlineVariant =>
      isDark ? AppColors.outlineVariantDark : AppColors.outlineVariant;
  Color get inputBg => isDark ? AppColors.inputBgDark : AppColors.inputBg;
  Color get topbarBorder =>
      isDark ? AppColors.dividerDark : const Color(0x80DCD9D9);
  Color get fuelContainer =>
      isDark ? AppColors.fuelContainerDark : AppColors.fuelContainerLight;

  // --- 语义色 ---
  Color get error => AppColors.error;
  Color get errorContainer =>
      isDark ? AppColors.errorContainerDark : AppColors.errorContainerLight;
  Color get onErrorContainer =>
      isDark ? AppColors.onErrorContainerDark : AppColors.onErrorContainerLight;
  Color get info => AppColors.info;
  Color get peak => AppColors.peak;
  Color get fuel => AppColors.fuel;

  @override
  EvPalette copyWith({Brightness? brightness, AccentTheme? accent}) =>
      EvPalette(
        brightness: brightness ?? this.brightness,
        accent: accent ?? this.accent,
      );

  @override
  EvPalette lerp(EvPalette? other, double t) {
    if (other == null) return this;
    // 主题切换是离散的（accent id / 亮度），不做插值，直接取目标态。
    return t < 0.5 ? this : other;
  }
}
