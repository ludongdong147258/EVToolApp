import 'package:flutter/material.dart';

/// 中性色板与功能色（浅色/深色两套静态值）。
///
/// 移植自 EVTool 小程序 src/_tokens.scss + src/styles/_theme.scss。
/// 品牌色（primary 等）不在此处 —— 由 [AccentTheme] 注入，见 app_palette.dart。
abstract final class AppColors {
  // --- 浅色 ---
  static const Color backgroundPale = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFF8F8F8);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF0F0F0);
  static const Color surfaceContainer = Color(0xFFEBEBEB);
  static const Color surfaceContainerHighest = Color(0xFFE0E0E0);
  static const Color surfaceVariant = Color(0xFFE0E0E0);
  static const Color onSurface = Color(0xFF1A1A1A);
  static const Color onSurfaceVariant = Color(0xFF444444);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF999999);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color outlineVariant = Color(0xFFCCCCCC);
  static const Color inputBg = Color(0xFFF5F5F5);
  static const Color secondaryContainerLight = Color(0xFFD1FAE5);
  static const Color fuelContainerLight = Color(0xFFEFEBE9);
  static const Color errorContainerLight = Color(0xFFFFDAD6);
  static const Color onErrorContainerLight = Color(0xFF93000A);

  // --- 深色 ---
  static const Color backgroundPaleDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF191919);
  static const Color surfaceCardDark = Color(0xFF1E1E1E);
  static const Color surfaceContainerLowDark = Color(0xFF262626);
  static const Color surfaceContainerDark = Color(0xFF2B2B2B);
  static const Color surfaceContainerHighestDark = Color(0xFF2E2E2E);
  static const Color surfaceVariantDark = Color(0xFF333333);
  static const Color onSurfaceDark = Color(0xFFEAEAEA);
  static const Color onSurfaceVariantDark = Color(0xFFC4C4C4);
  static const Color textSecondaryDark = Color(0xFFA0A0A0);
  static const Color textHintDark = Color(0xFF787878);
  static const Color dividerDark = Color(0xFF333333);
  static const Color outlineVariantDark = Color(0xFF3D3D3D);
  static const Color inputBgDark = Color(0xFF262626);
  static const Color fuelContainerDark = Color(0xFF3E2F2A);
  static const Color errorContainerDark = Color(0xFF5C1F1C);
  static const Color onErrorContainerDark = Color(0xFFFFB4AB);

  // --- 功能色（不随深浅色变化，与小程序一致） ---
  static const Color tertiary = Color(0xFFB45309);
  static const Color amber = Color(0xFFF59E0B);
  static const Color fuel = Color(0xFF795548);
  static const Color peak = Color(0xFFFE7D00);
  static const Color info = Color(0xFF409EFF);
  static const Color error = Color(0xFFBA1A1A);
  static const Color fastCharge = Color(0xFFF97316);
  static const Color homeCharge = Color(0xFF10B981);

  // --- 装备导购（移植小程序 $accent 价格色 / 券 pill 配色） ---
  static const Color goodsPrice = Color(0xFFF59E0B);
  static const Color goodsCoupon = Color(0xFFD97706);
  static const Color goodsCouponBg = Color(0xFFFFF7ED);

  // --- 支出类型色（移植 lib/constants.js COST_TYPE_COLORS） ---
  static const Color costTypeCharge = Color(0xFF10B981);
  static const Color costTypeInsurance = Color(0xFF409EFF);
  static const Color costTypeParking = Color(0xFFF59E0B);
  static const Color costTypeWash = Color(0xFFFE7D00);
  static const Color costTypeMaintenance = Color(0xFF047857);
  static const Color costTypeToll = Color(0xFFB45309);
  static const Color costTypeFine = Color(0xFFBA1A1A);
  static const Color costTypeParts = Color(0xFF795548);
  static const Color costTypeOther = Color(0xFF999999);

  /// 按支出类型 key 取色（charge/insurance/parking/wash/maintenance/
  /// toll/fine/parts/other，未知回退 other）。
  static Color costTypeColor(String key) => switch (key) {
    'charge' => costTypeCharge,
    'insurance' => costTypeInsurance,
    'parking' => costTypeParking,
    'wash' => costTypeWash,
    'maintenance' => costTypeMaintenance,
    'toll' => costTypeToll,
    'fine' => costTypeFine,
    'parts' => costTypeParts,
    _ => costTypeOther,
  };

  // --- 半透明（hero 卡内） ---
  static const Color onPrimaryA22 = Color(0x38FFFFFF); // 22% 白，圆钮底
  static const Color onPrimaryA28 = Color(0x47FFFFFF); // 28% 白，分隔线
  static const Color onPrimaryA85 = Color(0xD9FFFFFF); // 85% 白，标签/单位

  // --- 圆角刻度（rpx/2：8/16/24/48rpx → 4/8/12/24） ---
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 24;

  // --- 动效时长/曲线 ---
  static const Duration motionFast = Duration(milliseconds: 120);
  static const Duration motionBase = Duration(milliseconds: 220);
  static const Duration motionSlow = Duration(milliseconds: 320);
  static const Curve easeStandard = Cubic(0.2, 0, 0, 1);
  static const Curve easeOut = Cubic(0, 0, 0.2, 1);

  // --- 浮动底栏几何 ---
  static const double bottomNavHeight = 60;
  static const double bottomNavOffset = 16;
}
