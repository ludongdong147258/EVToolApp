class AppConstants {
  AppConstants._();

  static const String appName = 'VoltLedger';
  // 首次发表年份（版权声明起始年）；跨年后可改为区间，如 2026-${当前年}
  static const int copyrightStartYear = 2026;

  // ---------- Pro 订阅（RevenueCat） ----------
  /// RevenueCat entitlement 标识（须与后台 Entitlements 配置一致）。
  static const String proEntitlementId = 'voltledger_pro';

  /// 免费档每月 OCR 识别次数。
  static const int freeOcrMonthlyQuota = 5;

  /// 免费档车辆数量上限（备份导入不受限）。
  static const int freeVehicleLimit = 1;
}
