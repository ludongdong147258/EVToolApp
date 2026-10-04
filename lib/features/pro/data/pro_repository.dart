import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:ev_tool_app/core/constants/app_constants.dart';
import 'package:ev_tool_app/core/constants/env.dart';
import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/utils/logger.dart';

/// Pro 订阅状态与 RevenueCat 交互仓储。
///
/// 设计要点：
/// - RevenueCat 仅在有 key 时初始化（[initRevenueCat]，main.dart 传入 kv）；
///   缺 key 时视为全部解锁（dev 模式）。所有 `Purchases.*` 调用被
///   `sdkAvailable` 守卫，测试环境（不加载 .env）天然不会触碰平台通道。
/// - Pro 状态 KV 缓存（key `proStatus`，JSON bool）：entitlement 变化时写入，
///   `proStatusProvider.build()` 同步读缓存，冷启动/离线用上次值（宽限语义）。
/// - 无后端无登录：匿名 RC user，卸载重装靠 paywall 的 Restore 找回订阅。

/// 应用启动时调用（main.dart，dotenv 加载后，传入全局 kv）。
///
/// 有 key 才 configure RevenueCat，并注册 entitlement 变化监听：
/// 写 KV 缓存 + 通知已创建的 proStatusNotifier。
Future<void> initRevenueCat(KeyValueStore kv) async {
  if (!Env.hasRevenueCatKey) {
    appLogger.w('REVENUECAT_SDK_KEY missing — Pro features unlocked (dev)');
    return;
  }
  try {
    await Purchases.configure(PurchasesConfiguration(Env.revenueCatSdkKey));
    _configured = true;
    _listenerKv = kv;
    Purchases.addCustomerInfoUpdateListener((info) {
      final active =
          info.entitlements.all[AppConstants.proEntitlementId]?.isActive ??
          false;
      _onEntitlementChanged?.call(active);
      final kv = _listenerKv;
      if (kv != null) unawaited(_cacheProStatus(kv, active));
    });
  } on PlatformException catch (e) {
    appLogger.e('Failed to configure RevenueCat', error: e);
  }
}

// ---------- 库级共享状态（initRevenueCat 与仓储实例间传递） ----------

/// RevenueCat 是否已 configure（静态：仓储实例在 init 之后创建也能感知）。
bool _configured = false;

/// 监听回调写缓存用的 kv（configure 成功时赋值）。
KeyValueStore? _listenerKv;

/// entitlement 变化时通知 provider（ProStatusNotifier 注册/注销）。
void Function(bool active)? _onEntitlementChanged;

Future<void> _cacheProStatus(KeyValueStore kv, bool value) async {
  try {
    await kv.setJson(ProRepository.storageKey, value);
  } on Exception catch (e) {
    appLogger.e('Failed to cache pro status', error: e);
  }
}

// ---------- 仓储 ----------

/// 购买/恢复结果三态（+恢复无购买），UI 据此区分反馈文案。
enum ProActionResult { success, cancelled, failed, noPurchases }

class ProRepository {
  ProRepository(this._kv);

  static const String storageKey = 'proStatus';
  final KeyValueStore _kv;

  /// SDK 是否已配置（key 存在且 configure 成功）。
  bool get sdkAvailable => _configured;

  /// 缓存的 Pro 状态（无缓存/脏数据按 false 处理；无 key 时调用方走解锁分支）。
  bool getCachedProStatus() => _kv.getJson(storageKey) == true;

  /// 从 RevenueCat 拉取最新 entitlement 并写缓存；SDK 不可用/异常时返回缓存值。
  Future<bool> refresh() async {
    if (!sdkAvailable) return getCachedProStatus();
    try {
      final info = await Purchases.getCustomerInfo();
      final active =
          info.entitlements.all[AppConstants.proEntitlementId]?.isActive ??
          false;
      await _cacheProStatus(_kv, active);
      return active;
    } on PlatformException catch (e) {
      appLogger.e('Failed to refresh pro status', error: e);
      return getCachedProStatus();
    }
  }

  /// 当前 offering 的可选套餐；SDK 不可用/异常/为空返回 []。
  Future<List<Package>> getOfferings() async {
    if (!sdkAvailable) return const <Package>[];
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? const <Package>[];
    } on PlatformException catch (e) {
      appLogger.e('Failed to load offerings', error: e);
      return const <Package>[];
    }
  }

  /// 购买套餐；成功写缓存。取消/失败/entitlement 未激活分态返回（文案由 UI toast）。
  Future<ProActionResult> purchase(Package package) async {
    if (!sdkAvailable) return ProActionResult.failed;
    try {
      final info = await Purchases.purchasePackage(package);
      final active =
          info.entitlements.all[AppConstants.proEntitlementId]?.isActive ??
          false;
      if (!active) _logInactiveEntitlement(info, 'purchase');
      await _cacheProStatus(_kv, active);
      return active ? ProActionResult.success : ProActionResult.failed;
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return ProActionResult.cancelled;
      }
      appLogger.e('Purchase failed', error: e);
      return ProActionResult.failed;
    }
  }

  /// 恢复购买；调用成功但无 entitlement 视为无可恢复购买。
  Future<ProActionResult> restore() async {
    if (!sdkAvailable) return ProActionResult.failed;
    try {
      final info = await Purchases.restorePurchases();
      final active =
          info.entitlements.all[AppConstants.proEntitlementId]?.isActive ??
          false;
      if (!active) _logInactiveEntitlement(info, 'restore');
      await _cacheProStatus(_kv, active);
      return active ? ProActionResult.success : ProActionResult.noPurchases;
    } on PlatformException catch (e) {
      appLogger.e('Restore failed', error: e);
      return ProActionResult.failed;
    }
  }
}

// ---------- Provider ----------

/// 购买/恢复调用成功但目标 entitlement 未激活时的诊断日志：
/// 列出当前实际存在的 entitlement，便于发现标识不匹配或后台未挂产品。
void _logInactiveEntitlement(CustomerInfo info, String source) {
  final keys = info.entitlements.all.keys.join(', ');
  appLogger.w(
    '$source completed but entitlement "${AppConstants.proEntitlementId}" '
    'is not active. Current entitlements: [${keys.isEmpty ? 'none' : keys}]',
  );
}

final proRepositoryProvider = Provider<ProRepository>(
  (ref) => ProRepository(ref.watch(keyValueStoreProvider)),
);

/// Pro 状态：无 key（dev/测试）恒 true；否则同步读 KV 缓存。
class ProStatusNotifier extends Notifier<bool> {
  @override
  bool build() {
    final repo = ref.watch(proRepositoryProvider);
    // 注册 entitlement 监听：RC 后台变化（续订/退订）实时刷新 state。
    // dispose 时仅在回调仍是自己的情况下置空，避免误杀其他容器刚注册的回调。
    final handler = applyFromRevenueCat;
    _onEntitlementChanged = handler;
    ref.onDispose(() {
      if (_onEntitlementChanged == handler) _onEntitlementChanged = null;
    });
    return !repo.sdkAvailable ? true : repo.getCachedProStatus();
  }

  /// RC 监听回调 / 购买成功后调用：乐观更新 state。
  void applyFromRevenueCat(bool active) {
    if (state != active) state = active;
  }

  /// 手动刷新（paywall 打开时调用，拉最新 entitlement）。
  /// 无 SDK（dev/测试）时 no-op，保持"无 key 恒解锁"的默认语义。
  Future<void> refreshFromRevenueCat() async {
    if (!ref.read(proRepositoryProvider).sdkAvailable) return;
    final active = await ref.read(proRepositoryProvider).refresh();
    if (state != active) state = active;
  }
}

final proStatusProvider = NotifierProvider<ProStatusNotifier, bool>(
  ProStatusNotifier.new,
);
