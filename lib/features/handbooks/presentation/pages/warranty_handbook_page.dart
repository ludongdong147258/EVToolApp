import 'package:flutter/material.dart';

import 'package:ev_tool_app/core/domain/data/warranty_policy.dart';
import 'package:ev_tool_app/core/extensions/context_extensions.dart';
import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/gradient_hero_card.dart';

IconData _warrantyIcon(String name) => switch (name) {
  'directions_car' => Icons.directions_car_rounded,
  'battery_charging_full' => Icons.battery_charging_full_rounded,
  'verified_user' => Icons.verified_user_rounded,
  'science' => Icons.science_rounded,
  'compare_arrows' => Icons.compare_arrows_rounded,
  'warning' => Icons.warning_amber_rounded,
  'task_alt' => Icons.task_alt_rounded,
  'whatshot' => Icons.local_fire_department_rounded,
  _ => Icons.info_outline_rounded,
};

/// 三电质保政策手册页（移植小程序 warranty-handbook）：
/// 静态政策对照 + 品牌锚点跳转（仅点击跳转高亮，未做滚动跟随高亮 —— 与
/// 小程序的双向滚动同步相比为已知简化）。
class WarrantyHandbookPage extends StatefulWidget {
  const WarrantyHandbookPage({super.key});

  @override
  State<WarrantyHandbookPage> createState() => _WarrantyHandbookPageState();
}

class _WarrantyHandbookPageState extends State<WarrantyHandbookPage> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {
    for (final brand in warrantyBrands) brand.id: GlobalKey(),
  };
  late String _activeBrandId = warrantyBrands.first.id;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 品牌跳转（scrollIntoView 语义 → Scrollable.ensureVisible）。
  void _jumpTo(String brandId) {
    setState(() => _activeBrandId = brandId);
    final targetContext = _sectionKeys[brandId]?.currentContext;
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
    final lifetimeCount = warrantyBrands
        .where((brand) => brand.offersLifetimeWarranty)
        .length;
    final transferVoidCount = warrantyBrands
        .where((brand) => brand.voidsLifetimeOnTransfer)
        .length;
    final degradationCount = warrantyBrands
        .where((brand) => brand.hasDegradationStandard)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('EV Warranty Handbook')),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Check battery/motor/electronics warranty before buying: term and '
            'mileage limits, lifetime warranty conditions, degradation '
            'standards, and transfer rights at a glance.',
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          const SizedBox(height: 12),
          GradientHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Warranty quick reference by brand',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.onPrimaryA85,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      'Reference only · $warrantyDataDate',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.onPrimaryA85,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                HeroValue(value: '${warrantyBrands.length}', unit: 'brands'),
                const SizedBox(height: 16),
                HeroStatsRow(
                  items: [
                    HeroStatItem(
                      label: 'Lifetime',
                      value: '$lifetimeCount',
                      unit: 'brands',
                    ),
                    HeroStatItem(
                      label: 'Void on transfer',
                      value: '$transferVoidCount',
                      unit: 'brands',
                    ),
                    HeroStatItem(
                      label: 'Degradation',
                      value: '$degradationCount',
                      unit: 'brands',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _BaselineCard(baseline: warrantyBaseline),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final brand in warrantyBrands)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _BrandChip(
                      label: brand.name,
                      isActive: _activeBrandId == brand.id,
                      onTap: () => _jumpTo(brand.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final brand in warrantyBrands) ...[
            BrandCard(key: _sectionKeys[brand.id], brand: brand),
            const SizedBox(height: 12),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              warrantyDisclaimer,
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

/// 单个品牌卡（公开给单测与其他入口复用）。
class BrandCard extends StatelessWidget {
  const BrandCard({super.key, required this.brand});

  final WarrantyBrand brand;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    brand.name.substring(0, 1),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brand.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        brand.tagline,
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryChip(text: brand.summary.vehicle, isPrimary: false),
                _SummaryChip(text: brand.summary.powertrain, isPrimary: true),
              ],
            ),
            const SizedBox(height: 12),
            for (final field in warrantyFields)
              _FieldRow(
                icon: _warrantyIcon(field.icon),
                label: field.label,
                text: brand.fields[field.id] ?? '--',
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.text, required this.isPrimary});

  final String text;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = isPrimary ? palette.primary : palette.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.icon,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: palette.primary),
          const SizedBox(width: 6),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: palette.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _BaselineCard extends StatelessWidget {
  const _BaselineCard({required this.baseline});

  final WarrantyBaseline baseline;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              baseline.title,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              baseline.note,
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
            const SizedBox(height: 12),
            for (final rule in baseline.rules)
              _FieldRow(
                icon: _warrantyIcon(rule.icon),
                label: rule.label,
                text: rule.text,
              ),
          ],
        ),
      ),
    );
  }
}

class _BrandChip extends StatelessWidget {
  const _BrandChip({required this.label, required this.isActive, this.onTap});

  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? palette.secondaryContainer : palette.inputBg,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          border: Border.all(
            color: isActive ? palette.primaryContainer : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive
                ? palette.onSecondaryContainer
                : palette.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
