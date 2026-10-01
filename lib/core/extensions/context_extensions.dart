import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/theme/app_palette.dart';

extension BuildContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// 语义色板（品牌色随运行时 accent 切换）。
  EvPalette get palette =>
      Theme.of(this).extension<EvPalette>() ?? EvPalette.lightFallback;
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  void pop<T extends Object?>([T? result]) => Navigator.of(this).pop(result);
}
