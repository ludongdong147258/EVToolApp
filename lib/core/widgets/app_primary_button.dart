import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/extensions/context_extensions.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.text,
    this.onTap,
    this.backgroundColor,
    this.textColor,
    this.borderRadius = 12,
    this.height = 50,
    this.fontSize = 16,
  });

  final String text;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? textColor;
  final double borderRadius;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Semantics(
        button: true,
        label: text,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? palette.primaryContainer,
            foregroundColor: textColor ?? Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            elevation: 0,
            textStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(text),
        ),
      ),
    );
  }
}
