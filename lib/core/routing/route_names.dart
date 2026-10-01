/// 路由路径常量。
///
/// 命名对齐小程序页面（pages 目录同名）；shell 分支 4 个 tab 之外的均为
/// push 子页。
abstract final class RouteNames {
  // --- Shell 分支（4 tab） ---
  static const String records = '/';
  static const String costs = '/costs';
  static const String tools = '/tools';
  static const String profile = '/profile';

  // --- 充电记录域 ---
  static const String recordAdd = '/record/add';
  static const String chargeStats = '/charge-stats';
  static const String annualReport = '/annual-report';
  static const String chargeMap = '/charge-map';

  // --- 养车支出域 ---
  static const String costAdd = '/cost/add';
  static const String costReport = '/cost-report';

  // --- 车辆 / 备忘 ---
  static const String vehicles = '/vehicles';
  static const String inspectionMemo = '/inspection-memo';

  // --- 工具 ---
  static const String fuelEvCalc = '/fuel-ev-calc';
  static const String rangeCalc = '/range-calc';
  static const String peakValleyCalc = '/peak-valley-calc';
  static const String homeChargerCalc = '/home-charger-calc';
  static const String nearbyStations = '/nearby-stations';
  static const String modificationCompliance = '/modification-compliance';
  static const String warrantyHandbook = '/warranty-handbook';
  static const String equipment = '/equipment';

  // --- 我的 ---
  static const String profileEdit = '/profile/edit';
  static const String backupRestore = '/backup-restore';
  static const String settings = '/settings';
  static const String about = '/about';
  static const String agreement = '/agreement';
  static const String privacy = '/privacy';
}
