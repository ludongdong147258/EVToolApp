import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/domain/theme_colors.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/theme/app_palette.dart';
import 'package:ev_tool_app/core/theme/app_typography.dart';

/// Material 3 主题构建：品牌色由 [AccentTheme] 参数化，支持运行时换肤。
class AppTheme {
  AppTheme._();

  static ThemeData light(AccentTheme accent) =>
      _build(Brightness.light, accent);

  static ThemeData dark(AccentTheme accent) => _build(Brightness.dark, accent);

  static ThemeData _build(Brightness brightness, AccentTheme accent) {
    final palette = EvPalette(brightness: brightness, accent: accent);
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: palette.primary,
        onPrimary: Colors.white,
        primaryContainer: palette.primaryContainer,
        onPrimaryContainer: Colors.white,
        secondary: palette.secondary,
        onSecondary: Colors.white,
        secondaryContainer: palette.secondaryContainer,
        onSecondaryContainer: palette.onSecondaryContainer,
        surface: palette.surfaceCard,
        onSurface: palette.onSurface,
        surfaceContainerHighest: palette.surfaceContainerHighest,
        onSurfaceVariant: palette.onSurfaceVariant,
        outlineVariant: palette.outlineVariant,
        error: palette.error,
        onError: Colors.white,
        errorContainer: palette.errorContainer,
        onErrorContainer: palette.onErrorContainer,
      ),
      scaffoldBackgroundColor: palette.backgroundPale,
      extensions: [palette],
      textTheme: isDark ? AppTypography.dark : AppTypography.light,
      // 对齐小程序 TopBar：品牌色底 + 居中白色标题（18/w700）
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        titleTextStyle: (isDark ? AppTypography.dark : AppTypography.light)
            .titleLarge
            ?.copyWith(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.divider, thickness: 0.5),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: palette.textHint, fontSize: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primaryContainer,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: palette.primary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surfaceCard,
        modalBackgroundColor: palette.surfaceCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppColors.radiusXl),
          ),
        ),
        showDragHandle: false,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.onSurface,
        contentTextStyle: TextStyle(color: palette.backgroundPale),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : palette.surfaceContainerHighest,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.primaryContainer
              : palette.surfaceContainer,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.primaryContainer
              : Colors.transparent,
        ),
        side: BorderSide(color: palette.outlineVariant, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
      ),
    );
  }
}
