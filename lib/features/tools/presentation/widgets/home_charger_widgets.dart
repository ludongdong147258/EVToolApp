import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/domain/numbers.dart' show formatMoney;
import 'package:ev_tool_app/core/theme/app_colors.dart';

/* 向导共 3 步：1 安装详情 → 2 环境条件 → 3 估算结果 */
const int totalSteps = 3;

const Map<int, String> stepTitles = {
  1: 'Installation',
  2: 'Site conditions',
  3: 'Estimate',
};

const Map<int, int> stepPercent = {1: 33, 2: 66, 3: 100};

/* 进度卡副文案（仅第 2/3 步有） */
const Map<int, String> stepNotes = {
  2: 'Tell us about your install site for a more accurate estimate.',
  3: 'Calculated automatically from your site conditions and add-ons',
};

/// 步骤进度卡：x/3 + 标题 + 百分比 + 进度条。
class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final percent = stepPercent[step] ?? 0;
    final note = stepNotes[step];

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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: palette.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$step / $totalSteps',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: palette.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stepTitles[step] ?? '',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$percent%',
                  style: TextStyle(fontSize: 12, color: palette.textHint),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 6,
                backgroundColor: palette.surfaceContainerHighest,
                color: palette.primaryContainer,
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(
                note,
                style: TextStyle(fontSize: 11, color: palette.textHint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 已保存测算入口行。
class HistoryEntry extends StatelessWidget {
  const HistoryEntry({super.key, required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: palette.surfaceCard,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
        child: Row(
          children: [
            Icon(Icons.save_outlined, size: 18, color: palette.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Saved estimates ($count)',
                style: TextStyle(fontSize: 13, color: palette.onSurface),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: palette.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// 单选项卡片（功率 / 安装位置共用），选中态高亮 + 角标。
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  final bool isSelected;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? palette.secondaryContainer : palette.inputBg,
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            border: Border.all(
              color: isSelected ? palette.primaryContainer : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(child: child),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: palette.primaryContainer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 环境条件开关行：图标 + 标题 + 增项价 + Switch。
class ConditionRow extends StatelessWidget {
  const ConditionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.price,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int price;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: palette.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: palette.textHint),
                ),
              ],
            ),
          ),
          Text(
            '+${formatMoney(price)}',
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// 总额卡：大数字 + 明细行 + 可选提示。
class TotalCard extends StatelessWidget {
  const TotalCard({
    super.key,
    required this.label,
    required this.total,
    this.lines = const <(String, int)>[],
    this.hint,
  });

  final String label;
  final int total;
  final List<(String, int)> lines;
  final String? hint;

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
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              formatMoney(total),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: palette.onSurface,
              ),
            ),
            for (final line in lines) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    line.$1,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                  Text(
                    formatMoney(line.$2),
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint!,
                style: TextStyle(fontSize: 11, color: palette.textHint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DetailLine extends StatelessWidget {
  const DetailLine({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: palette.onSurface)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.onSurface,
          ),
        ),
      ],
    );
  }
}
