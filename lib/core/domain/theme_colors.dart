/// 品牌配色注册表（纯数据 + 纯函数，无副作用）
///
/// 移植自 EVTool 小程序 src/lib/themeColors.js；
/// 深色 hero 渐变值来自 src/styles/_accents.scss / _theme.scss。
library;

/// 单套品牌配色。
///
/// [primary] 高亮/图标；[primaryContainer] 按钮/选中态（白字对比度 ≥ 4.5:1）；
/// [secondary] 深色图标；[secondaryContainer]/[onSecondaryContainer] 标签容器浅色态；
/// [darkSecondaryContainer]/[darkOnSecondaryContainer] 深色模式覆盖。
class AccentTheme {
  const AccentTheme({
    required this.id,
    required this.name,
    required this.primary,
    required this.primaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.darkSecondaryContainer,
    required this.darkOnSecondaryContainer,
    required this.darkHeroGradientStart,
    required this.darkHeroGradientEnd,
  });

  final String id;
  final String name;
  final int primary;
  final int primaryContainer;
  final int secondary;
  final int secondaryContainer;
  final int onSecondaryContainer;
  final int darkSecondaryContainer;
  final int darkOnSecondaryContainer;
  final int darkHeroGradientStart;
  final int darkHeroGradientEnd;

  /// 浅色模式 hero 渐变（135deg primary → primaryContainer）。
  int get heroGradientStart => primary;

  /// 浅色模式 hero 渐变终点。
  int get heroGradientEnd => primaryContainer;
}

/// 默认主题（green）单例常量。
const AccentTheme defaultAccentTheme = AccentTheme(
  id: 'green',
  name: 'Aurora Green',
  primary: 0xFF10B981,
  primaryContainer: 0xFF059669,
  secondary: 0xFF047857,
  secondaryContainer: 0xFFD1FAE5,
  onSecondaryContainer: 0xFF047857,
  darkSecondaryContainer: 0xFF064E3B,
  darkOnSecondaryContainer: 0xFF6EE7B7,
  darkHeroGradientStart: 0xFF0C9268,
  darkHeroGradientEnd: 0xFF065F46,
);

/// 主题注册表（与小程序 _accents.scss 同名 class 一一对应）。
const List<AccentTheme> accentThemes = [
  defaultAccentTheme,
  AccentTheme(
    id: 'blue',
    name: 'Deep Blue',
    primary: 0xFF3B82F6,
    primaryContainer: 0xFF2563EB,
    secondary: 0xFF1D4ED8,
    secondaryContainer: 0xFFDBEAFE,
    onSecondaryContainer: 0xFF1E40AF,
    darkSecondaryContainer: 0xFF1E3A8A,
    darkOnSecondaryContainer: 0xFF93C5FD,
    darkHeroGradientStart: 0xFF2563EB,
    darkHeroGradientEnd: 0xFF1E3A8A,
  ),
  AccentTheme(
    id: 'orange',
    name: 'Sunset Orange',
    primary: 0xFFF97316,
    primaryContainer: 0xFFC2410C,
    secondary: 0xFF9A3412,
    secondaryContainer: 0xFFFFEDD5,
    onSecondaryContainer: 0xFF9A3412,
    darkSecondaryContainer: 0xFF431407,
    darkOnSecondaryContainer: 0xFFFDBA74,
    darkHeroGradientStart: 0xFFC2410C,
    darkHeroGradientEnd: 0xFF7C2D12,
  ),
  AccentTheme(
    id: 'purple',
    name: 'Stellar Purple',
    primary: 0xFF8B5CF6,
    primaryContainer: 0xFF7C3AED,
    secondary: 0xFF6D28D9,
    secondaryContainer: 0xFFEDE9FE,
    onSecondaryContainer: 0xFF5B21B6,
    darkSecondaryContainer: 0xFF2E1065,
    darkOnSecondaryContainer: 0xFFC4B5FD,
    darkHeroGradientStart: 0xFF7C3AED,
    darkHeroGradientEnd: 0xFF4C1D95,
  ),
  AccentTheme(
    id: 'pink',
    name: 'Sakura Pink',
    primary: 0xFFEC4899,
    primaryContainer: 0xFFBE185D,
    secondary: 0xFF9D174D,
    secondaryContainer: 0xFFFCE7F3,
    onSecondaryContainer: 0xFF9D174D,
    darkSecondaryContainer: 0xFF500724,
    darkOnSecondaryContainer: 0xFFF9A8D4,
    darkHeroGradientStart: 0xFFBE185D,
    darkHeroGradientEnd: 0xFF831843,
  ),
  AccentTheme(
    id: 'cyan',
    name: 'Cyber Cyan',
    primary: 0xFF06B6D4,
    primaryContainer: 0xFF0E7490,
    secondary: 0xFF155E75,
    secondaryContainer: 0xFFCFFAFE,
    onSecondaryContainer: 0xFF155E75,
    darkSecondaryContainer: 0xFF164E63,
    darkOnSecondaryContainer: 0xFF67E8F9,
    darkHeroGradientStart: 0xFF0E7490,
    darkHeroGradientEnd: 0xFF155E75,
  ),
];

/// 默认主题 id。
const String defaultAccentId = 'green';

/// 校验主题 id：合法原样返回；非法/未知返回 null。
String? normalizeAccentId(dynamic raw) {
  if (raw is! String) return null;
  return accentThemes.any((item) => item.id == raw) ? raw : null;
}

/// 按 id 取主题（未知 id 兜底默认主题，绝不返回空）。
AccentTheme getAccentById(String? id) {
  final normalized = normalizeAccentId(id);
  if (normalized != null) {
    return accentThemes.firstWhere((item) => item.id == normalized);
  }
  return accentThemes.firstWhere((item) => item.id == defaultAccentId);
}
