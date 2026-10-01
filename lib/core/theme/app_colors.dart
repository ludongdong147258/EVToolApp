import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette — 科技蓝绿
  static const Color primaryTeal = Color(0xFF00B8A9);
  static const Color darkTeal = Color(0xFF062A2B);
  static const Color lightTeal = Color(0xFFB2F0EA);

  // Backgrounds
  static const Color backgroundCoolWhite = Color(0xFFF7FAFB);
  static const Color backgroundTeal = Color(0xFFE6F6F5);
  static const Color backgroundDark = Color(0xFF101418);
  static const Color cardDark = Color(0xFF1C2328);

  // Text
  static const Color textPrimary = Color(0xFF22282B);
  static const Color textSecondary = Color(0xFF5A6469);
  static const Color textTertiary = Color(0xFF98A2A6);
  static const Color textPlaceholder = Color(0xFF7C8B90);

  // Accents
  static const Color orange = Color(0xFFFF9C00);
  static const Color blue = Color(0xFF2F6DF6);

  // Semantic
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57F17);
  static const Color error = Color(0xFFC62828);

  // Borders & overlays
  static const Color borderGray = Color(0x1A000000);
  static const Color overlayDark = Color(0x80000000);
  static const Color glassWhite = Color(0x80FFFFFF);

  // Surfaces
  static const Color surfaceLight = Color(0xFFE9EEF0);
  static const Color surfaceGray = Color(0xFFEFF2F3);
  static const Color searchBarBackground = Color(0xFFF1F4F5);

  // Shadow
  static const Color shadowLight = Color(0x0F000000);

  // Theme-compatible aliases
  static const Color primary = primaryTeal;
  static const Color primaryLight = lightTeal;
  static const Color accent = blue;
  static const Color surface = backgroundCoolWhite;
  static const Color surfaceDark = backgroundDark;
}
