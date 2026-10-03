import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';

/// 主流电动车电池容量档位（kWh）：15-90 每 5 kWh 一档，
/// 大电池顶部放宽到 10 kWh 粒度（与小程序两页同源）。
const List<int> batteryOptions = <int>[
  15,
  20,
  25,
  30,
  35,
  40,
  45,
  50,
  55,
  60,
  65,
  70,
  75,
  80,
  85,
  90,
  100,
  110,
  120,
  150,
];

/// 综合折扣表述：1 → 无折扣；0.45 → ≈45%。
String formatDiscount(double factor) {
  if (factor >= 1) return 'No discount';
  return '≈${formatPlainNumber((factor * 1000).round() / 10)}%';
}

/// 数值展示：整数值省略小数位（342.0 → "342"；342.5 → "342.5"）。
String formatPlainNumber(double value) {
  return value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
}

/// 计算器卡片：标题行（图标 + 标题）+ 内容。
class CalcCard extends StatelessWidget {
  const CalcCard({
    super.key,
    required this.title,
    required this.icon,
    this.iconColor,
    this.subtitle,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color? iconColor;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      color: palette.surfaceCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor ?? palette.textSecondary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: palette.textHint),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// 数字输入行：标签 + 输入框（非法时红框，保留上次结果由页面负责）。
class CalcTextField extends StatelessWidget {
  const CalcTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = controller.text;
    final num? parsed = text.isEmpty ? null : _tryParse(text);
    final isInvalid = text.isNotEmpty && (parsed == null || parsed <= 0);
    final borderColor = isInvalid ? palette.error : palette.divider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: palette.textSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: TextStyle(fontSize: 15, color: palette.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 14, color: palette.textHint),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            filled: true,
            fillColor: palette.inputBg,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              borderSide: BorderSide(color: borderColor, width: 1.5),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  num? _tryParse(String text) {
    return double.tryParse(text.trim());
  }
}

/// 选项 chip（工况选择 / 预设值，胶囊样式对齐小程序 .chip），可选副文本（系数 ×f）。
class CalcChip extends StatelessWidget {
  const CalcChip({
    super.key,
    required this.label,
    this.sublabel,
    required this.isSelected,
    this.onTap,
  });

  final String label;
  final String? sublabel;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? palette.secondaryContainer : palette.inputBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? palette.primaryContainer : Colors.transparent,
          ),
        ),
        // 名称与系数同行（对齐小程序 .chip flex row），单行不换行
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? palette.onSecondaryContainer
                      : palette.onSurfaceVariant,
                ),
              ),
            ),
            if (sublabel != null) ...[
              const SizedBox(width: 4),
              Text(
                sublabel!,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? palette.onSecondaryContainer
                      : palette.textHint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 品牌色滑块（activeColor 取品牌主色，对齐小程序 accent PRIMARY）。
class CalcSlider extends StatelessWidget {
  const CalcSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        // 去掉轨道两侧默认留白，滑块贴齐内容区
        padding: EdgeInsets.zero,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        activeColor: palette.primary,
        inactiveColor: palette.surfaceContainerHighest,
        onChanged: onChanged,
      ),
    );
  }
}

/// 滑块两端刻度。
class SliderScaleRow extends StatelessWidget {
  const SliderScaleRow({super.key, required this.start, required this.end});

  final String start;
  final String end;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(start, style: TextStyle(fontSize: 11, color: palette.textHint)),
        Text(end, style: TextStyle(fontSize: 11, color: palette.textHint)),
      ],
    );
  }
}

/// 底部免责声明。
class CalcDisclaimer extends StatelessWidget {
  const CalcDisclaimer(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: palette.textHint, height: 1.5),
      ),
    );
  }
}

/// 电池容量档位弹层（我的车容量不在档位时作为首格）。
Future<void> showBatteryOptionsSheet(
  BuildContext context, {
  required double current,
  double? myVehicleBattery,
  required ValueChanged<double> onSelect,
}) {
  final myVehicle = myVehicleBattery;
  return showAppSheet(
    context: context,
    title: 'Select battery capacity',
    builder: (sheetContext) => AppSheetScrollBody(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (myVehicle is double)
            CalcChip(
              label: '${formatPlainNumber(myVehicle)} kWh · My car',
              isSelected: myVehicle == current,
              onTap: () {
                Navigator.of(sheetContext).pop();
                onSelect(myVehicle);
              },
            ),
          for (final capacity in batteryOptions)
            CalcChip(
              label: '$capacity kWh',
              isSelected: capacity == current,
              onTap: () {
                Navigator.of(sheetContext).pop();
                onSelect(capacity.toDouble());
              },
            ),
        ],
      ),
    ),
  );
}
