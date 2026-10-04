import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:ev_tool_app/core/theme/app_colors.dart';
import 'package:ev_tool_app/core/widgets/app_primary_button.dart';
import 'package:ev_tool_app/core/widgets/app_sheet.dart';
import 'package:ev_tool_app/core/widgets/app_toast.dart';
import 'package:ev_tool_app/features/pro/data/pro_repository.dart';

/// 统一 Pro 门控入口：已 Pro 返回 true；否则弹 paywall，购买/恢复成功返回 true。
Future<bool> ensurePro(BuildContext context, WidgetRef ref) async {
  if (ref.read(proStatusProvider)) return true;
  return showPaywallSheet(context);
}

/// 弹出付费墙；返回是否已解锁（购买/恢复成功，或弹层打开时已是 Pro）。
Future<bool> showPaywallSheet(BuildContext context) async {
  final unlocked = await showAppSheet<bool>(
    context: context,
    title: 'EV Pro',
    builder: (context) => const _PaywallSheet(),
  );
  return unlocked ?? false;
}

/// 当前 offering 的可选套餐（无 key / 失败返回空列表）。
final paywallOfferingsProvider = FutureProvider<List<Package>>(
  (ref) => ref.watch(proRepositoryProvider).getOfferings(),
);

/// 方案展示顺序（短周期在前；custom/unknown 排最后）。
const Map<PackageType, int> _planOrder = {
  PackageType.weekly: 0,
  PackageType.monthly: 1,
  PackageType.twoMonth: 2,
  PackageType.threeMonth: 3,
  PackageType.sixMonth: 4,
  PackageType.annual: 5,
  PackageType.lifetime: 6,
};

/// 方案卡标题：按 packageType 推导，custom 回退 package identifier。
String _planTitle(Package p) => switch (p.packageType) {
  PackageType.weekly => 'Weekly',
  PackageType.monthly => 'Monthly',
  PackageType.twoMonth => '2 Months',
  PackageType.threeMonth => '3 Months',
  PackageType.sixMonth => '6 Months',
  PackageType.annual => 'Yearly',
  PackageType.lifetime => 'Lifetime',
  _ => p.identifier,
};

class _PaywallSheet extends ConsumerStatefulWidget {
  const _PaywallSheet();

  @override
  ConsumerState<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<_PaywallSheet> {
  Package? _selected;
  bool _busy = false;

  static const List<(IconData, String)> _perks = [
    (Icons.receipt_long_rounded, 'Unlimited receipt OCR scans'),
    (Icons.share_rounded, 'Annual report poster export'),
    (Icons.table_view_rounded, 'CSV export for records'),
    (Icons.directions_car_rounded, 'Unlimited vehicles in your garage'),
  ];

  @override
  void initState() {
    super.initState();
    // 打开时拉最新 entitlement（处理沙盒续订/后台状态变化）
    unawaited(ref.read(proStatusProvider.notifier).refreshFromRevenueCat());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPro = ref.watch(proStatusProvider);
    final sdkAvailable = ref.watch(proRepositoryProvider).sdkAvailable;
    final offerings = ref.watch(paywallOfferingsProvider);

    if (isPro) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('Pro is active', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Thanks for supporting VoltLedger!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (!sdkAvailable) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pro features unlocked', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Development build — no store connection.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._perks.map(_buildPerkRow),
          const SizedBox(height: 16),
          offerings.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, _) => _buildRetryPlaceholder(theme),
            data: (packages) => _buildPlanList(theme, packages),
          ),
          const SizedBox(height: 12),
          AppPrimaryButton(
            text: _selected == null ? 'Choose a plan' : 'Subscribe',
            onTap: _busy || _selected == null ? null : _purchase,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _busy ? null : _restore,
              child: const Text('Restore Purchases'),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Cancel anytime. Manage your subscription in the App Store.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerkRow((IconData, String) perk) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(perk.$1, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(perk.$2, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  /// 完全按 RC offering 的 availablePackages 渲染（配什么出什么），默认选年付。
  Widget _buildPlanList(ThemeData theme, List<Package> packages) {
    if (packages.isEmpty) return _buildRetryPlaceholder(theme);

    final plans = [...packages]
      ..sort(
        (a, b) =>
            (_planOrder[a.packageType] ?? 99) -
            (_planOrder[b.packageType] ?? 99),
      );
    final annual = plans.where((p) => p.packageType == PackageType.annual);
    final effectiveSelected =
        _selected ?? (annual.isEmpty ? plans.first : annual.first);
    _selected = effectiveSelected; // 供 Subscribe 按钮使用

    return Column(
      children: [
        for (final plan in plans)
          _PlanCard(
            plan: plan,
            isSelected: plan == effectiveSelected,
            onTap: () => setState(() => _selected = plan),
          ),
      ],
    );
  }

  Widget _buildRetryPlaceholder(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          'Plans are unavailable. Check your connection and try again.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Future<void> _purchase() async {
    final plan = _selected;
    if (plan == null) return;
    setState(() => _busy = true);
    final ok = await ref.read(proRepositoryProvider).purchase(plan);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      showAppToast(context, 'Pro unlocked!');
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    final ok = await ref.read(proRepositoryProvider).restore();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      showAppToast(context, 'Pro restored!');
      Navigator.of(context).pop(true);
    } else {
      showAppToast(context, 'No purchases to restore.');
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  final Package plan;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAnnual = plan.packageType == PackageType.annual; // Best value 标记

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _planTitle(plan),
                          style: theme.textTheme.titleSmall,
                        ),
                        if (isAnnual) ...[
                          const SizedBox(width: 8),
                          _BestValueTag(theme: theme),
                        ],
                      ],
                    ),
                    Text(
                      plan.storeProduct.priceString,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BestValueTag extends StatelessWidget {
  const _BestValueTag({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Text(
        'Best value',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
