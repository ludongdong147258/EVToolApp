/// 充电装备分类（keyword 为拼多多搜索词）。
///
/// 移植小程序 src/pages/equipment/index.js 的 CATEGORIES 常量。
class EquipmentCategory {
  const EquipmentCategory({
    required this.id,
    required this.title,
    required this.keyword,
  });

  final String id;
  final String title;
  final String keyword;
}

/// 充电装备分类 Tab（6 类，与小程序一致）
const List<EquipmentCategory> equipmentCategories = [
  EquipmentCategory(id: 'charger-gun', title: 'Charging gun', keyword: '充电枪'),
  EquipmentCategory(id: 'portable', title: 'Travel charger', keyword: '随车充'),
  EquipmentCategory(
    id: 'home-pile',
    title: 'Home charging station',
    keyword: '家充桩',
  ),
  EquipmentCategory(
    id: 'accessories',
    title: 'Car accessories',
    keyword: '车载配件',
  ),
  EquipmentCategory(id: 'cables', title: 'Charging cables', keyword: '充电线材'),
  EquipmentCategory(id: 'power-bank', title: 'Jump starters', keyword: '应急电源'),
];

/// 首次进入免责声明文案（iOS 版去掉小程序跳转表述）
const String equipmentTipText =
    'Product data on this page comes from the Pinduoduo open platform — '
    'curated third-party listings with coupons. Prices and offers are subject '
    'to the actual Pinduoduo page. Tapping a product opens Pinduoduo to '
    'complete the purchase.';

/// 骨架屏卡数量（双列 × 3 行）
const int equipmentSkeletonCount = 6;
