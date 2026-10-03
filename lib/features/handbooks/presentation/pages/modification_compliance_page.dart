import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/domain/data/modification_compliance.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/theme/app_palette.dart';
import 'package:ev_tool_app/core/widgets/gradient_hero_card.dart';

/// Hero 三列短标签（category.title 6 字在小屏三列内可能换行）。
const Map<String, String> _heroStatLabel = {
  'legal': 'Legal',
  'register': 'Registration',
  'illegal': 'Illegal',
};

/// 备案要求胶囊语义色：按合规等级映射
/// （legal 全为「否」、register 为「是/视政策」、illegal 全为「不允许」）。
const Map<String, _Tone> _chipTone = {
  'legal': _Tone.ok,
  'register': _Tone.warn,
  'illegal': _Tone.bad,
};

enum _Tone { ok, warn, bad, info, neutral }

IconData _categoryIcon(String name) => switch (name) {
  'check_circle' => Icons.check_circle_rounded,
  'warning' => Icons.warning_amber_rounded,
  'close' => Icons.close_rounded,
  'directions_car' => Icons.directions_car_rounded,
  'battery_charging_full' => Icons.battery_charging_full_rounded,
  'verified_user' => Icons.verified_user_rounded,
  'science' => Icons.science_rounded,
  'compare_arrows' => Icons.compare_arrows_rounded,
  'task_alt' => Icons.task_alt_rounded,
  'whatshot' => Icons.local_fire_department_rounded,
  _ => Icons.info_outline_rounded,
};

Color _toneColor(_Tone tone, EvPalette palette) => switch (tone) {
  _Tone.ok => AppColors.costTypeCharge,
  _Tone.warn => AppColors.amber,
  _Tone.bad => palette.error,
  _Tone.info => AppColors.info,
  _Tone.neutral => palette.textHint,
};

_Tone _riskTone(String level) => switch (level) {
  'Low' => _Tone.info,
  'Medium' => _Tone.warn,
  'High' => _Tone.bad,
  _ => _Tone.neutral,
};

/// 分区图标色：legal 走品牌配色（随主题切换），其余为固定语义色。
Color _categoryColor(String categoryId, EvPalette palette) =>
    categoryId == 'legal'
    ? palette.primary
    : categoryId == 'register'
    ? AppColors.amber
    : palette.error;

/// 语义色胶囊（备案要求 / 风险等级徽章共用形态）。
class _ToneBadge extends StatelessWidget {
  const _ToneBadge({required this.text, required this.tone});

  final String text;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(tone, context.palette);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
  }
}

/// 改装合规查询页（移植小程序 modification-compliance）：
/// 静态对照表 + 分区锚点跳转。
class ModificationCompliancePage extends StatefulWidget {
  const ModificationCompliancePage({super.key});

  @override
  State<ModificationCompliancePage> createState() =>
      _ModificationCompliancePageState();
}

class _ModificationCompliancePageState
    extends State<ModificationCompliancePage> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {
    for (final category in modCategories) category.id: GlobalKey(),
  };
  String _activeCategory = modCategories.first.id;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 分区跳转（scrollIntoView 语义 → Scrollable.ensureVisible）。
  void _jumpTo(String categoryId) {
    setState(() => _activeCategory = categoryId);
    final targetContext = _sectionKeys[categoryId]?.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: AppColors.motionBase,
        curve: AppColors.easeStandard,
        alignment: 0.1,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final totalCount = modificationItems.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Mod Compliance Check')),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Check compliance before modifying: legal items are safe to install, '
            'registration-required items must be filed first, and illegal items '
            'are best avoided.',
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          const SizedBox(height: 12),
          GradientHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Common modifications at a glance',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onPrimaryA85,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                HeroValue(value: '$totalCount', unit: 'items'),
                const SizedBox(height: 16),
                HeroStatsRow(
                  items: [
                    for (final category in modCategories)
                      HeroStatItem(
                        label: _heroStatLabel[category.id] ?? category.id,
                        value: '${getItemsByCategory(category.id).length}',
                        unit: 'items',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in modCategories)
                _JumpChip(
                  label: _heroStatLabel[category.id] ?? category.title,
                  icon: _categoryIcon(category.icon),
                  iconColor: _categoryColor(category.id, palette),
                  isActive: _activeCategory == category.id,
                  onTap: () => _jumpTo(category.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (final category in modCategories) ...[
            _CategorySection(
              key: _sectionKeys[category.id],
              category: category,
            ),
            const SizedBox(height: 16),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              modComplianceDisclaimer,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: palette.textHint),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _JumpChip extends StatelessWidget {
  const _JumpChip({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.isActive,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? palette.secondaryContainer : palette.inputBg,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          border: Border.all(
            color: isActive ? palette.primaryContainer : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? palette.onSecondaryContainer : iconColor,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive
                    ? palette.onSecondaryContainer
                    : palette.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({super.key, required this.category});

  final ModCategory category;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _categoryIcon(category.icon),
              size: 20,
              color: _categoryColor(category.id, palette),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.title,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    category.desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final item in getItemsByCategory(category.id)) ...[
          _ItemCard(item: item),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final ModificationItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = _chipTone[item.category] ?? _Tone.neutral;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Flexible(
                  child: _ToneBadge(text: item.needRegister, tone: tone),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _RiskRow(
              label: 'Annual inspection risk',
              level: item.inspectionRisk,
            ),
            const SizedBox(height: 6),
            _RiskRow(label: 'Enforcement risk', level: item.policeRisk),
            const SizedBox(height: 10),
            Text(
              item.note,
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  const _RiskRow({required this.label, required this.level});

  final String label;
  final String level;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
        ),
        const Spacer(),
        _ToneBadge(text: level, tone: _riskTone(level)),
      ],
    );
  }
}
