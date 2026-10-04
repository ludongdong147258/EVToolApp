import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:ev_tool_app/core/domain/date_utils.dart';
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
/// autoDispose：每次打开 paywall 重新拉取，失败后可重试不缓存 error。
final paywallOfferingsProvider = FutureProvider.autoDispose<List<Package>>(
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

/// 到期时间 → "Feb 12, 2027"（复用 date_utils 英文月份缩写）。
String _formatExpiration(DateTime d) =>
    '${monthShortNames[d.month - 1]} ${d.day}, ${d.year}';

class _PaywallSheet extends ConsumerStatefulWidget {
  const _PaywallSheet();

  @override
  ConsumerState<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<_PaywallSheet> {
  Package? _selected;
  bool _busy = false;
  ({DateTime? expires, bool willRenew})? _proExpiration;

  static const List<(IconData, String)> _perks = [
    (Icons.receipt_long_rounded, 'Unlimited receipt OCR scans'),
    (Icons.share_rounded, 'Annual report poster export'),
    (Icons.table_view_rounded, 'CSV export for records'),
    (Icons.directions_car_rounded, 'Unlimited vehicles in your garage'),
  ];

  @override
  void initState() {
    super.initState();
    // 先用 KV 缓存同步初始化有效期（离线/秒开），再实时拉取覆盖
    _proExpiration = ref.read(proRepositoryProvider).getCachedExpiration();
    // 打开时拉最新 entitlement（处理沙盒续订/后台状态变化）
    unawaited(ref.read(proStatusProvider.notifier).refreshFromRevenueCat());
    // 已订阅时加载有效期（RC 有 customerInfo 缓存，代价低）
    unawaited(_loadExpiration());
  }

  Future<void> _loadExpiration() async {
    final expiration = await ref.read(proRepositoryProvider).proExpiration();
    if (mounted && expiration != null) {
      setState(() => _proExpiration = expiration);
    }
  }

  /// 有效期文案：已过期 → Expired；续订中 → Renews；已取消续订 → Expires；
  /// 无到期信息（终身/未加载）返回 null。
  String? get _expirationLabel {
    final expiration = _proExpiration;
    final expires = expiration?.expires;
    if (expires == null) return null;
    final date = _formatExpiration(expires);
    if (expires.isBefore(DateTime.now())) return 'Expired $date';
    return expiration!.willRenew ? 'Renews $date' : 'Expires $date';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPro = ref.watch(proStatusProvider);
    final sdkAvailable = ref.watch(proRepositoryProvider).sdkAvailable;
    final offerings = ref.watch(paywallOfferingsProvider);

    // 弹层期间 entitlement 变为激活（Restore/后台刷新成功）→ 自动关闭并放行门控，
    // 避免"页面已显示 Pro is active 但用户关闭后仍被拦"的误拦。
    ref.listen(proStatusProvider, (prev, next) {
      if (next && prev != true && mounted) {
        Navigator.of(context).pop(true);
      }
    });
    // 套餐数据到达且尚未选择时，默认选年付（postFrame 避免在 build 中改状态）。
    ref.listen(paywallOfferingsProvider, (prev, next) {
      final packages = next.value;
      if (packages == null || _selected != null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selected != null) return;
        final plans = _sortedPlans(packages);
        if (plans.isEmpty) return;
        final annual = plans.where((p) => p.packageType == PackageType.annual);
        setState(() => _selected = annual.isEmpty ? plans.first : annual.first);
      });
    });

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
            // 有效期：续订中 → Renews；已取消续订 → Expires；终身/未知 → 不显示
            if (_expirationLabel case final label?) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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

  /// 按 _planOrder 排序（短周期在前；custom/unknown 排最后）。
  List<Package> _sortedPlans(List<Package> packages) => [...packages]
    ..sort(
      (a, b) =>
          (_planOrder[a.packageType] ?? 99) - (_planOrder[b.packageType] ?? 99),
    );

  /// 完全按 RC offering 的 availablePackages 渲染（配什么出什么）。
  Widget _buildPlanList(ThemeData theme, List<Package> packages) {
    if (packages.isEmpty) return _buildRetryPlaceholder(theme);

    final plans = _sortedPlans(packages);
    return Column(
      children: [
        for (final plan in plans)
          _PlanCard(
            plan: plan,
            isSelected: plan == _selected,
            onTap: () => setState(() => _selected = plan),
          ),
      ],
    );
  }

  Widget _buildRetryPlaceholder(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        // 点击重试：invalidate 重新拉取（provider 已 autoDispose，不缓存 error）
        child: InkWell(
          onTap: () => ref.invalidate(paywallOfferingsProvider),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Plans are unavailable. Tap to retry.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _purchase() async {
    final plan = _selected;
    if (plan == null) return;
    setState(() => _busy = true);
    final result = await ref.read(proRepositoryProvider).purchase(plan);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case ProActionResult.success:
        showAppToast(context, 'Pro unlocked!');
        Navigator.of(context).pop(true);
      case ProActionResult.cancelled:
        break; // 用户主动取消，无需反馈
      case ProActionResult.failed:
        showAppToast(context, 'Purchase failed. Please try again');
      case ProActionResult.noPurchases:
        break; // purchase 不产生该态，防御
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    final result = await ref.read(proRepositoryProvider).restore();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case ProActionResult.success:
        showAppToast(context, 'Pro restored!');
        Navigator.of(context).pop(true);
      case ProActionResult.noPurchases:
        showAppToast(context, 'No purchases to restore.');
      case ProActionResult.failed:
        showAppToast(context, 'Restore failed. Check your connection');
      case ProActionResult.cancelled:
        break; // restore 无取消语义，防御
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
