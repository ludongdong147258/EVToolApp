import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/extensions/context_extensions.dart';

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    this.hint = '搜索...',
    this.controller,
    this.onChanged,
    this.onSubmitted,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: palette.inputBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: palette.textHint, fontSize: 14),
          prefixIcon: Icon(Icons.search, size: 20, color: palette.textHint),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
