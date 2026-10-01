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
  EquipmentCategory(id: 'charger-gun', title: '充电枪', keyword: '充电枪'),
  EquipmentCategory(id: 'portable', title: '随车充', keyword: '随车充'),
  EquipmentCategory(id: 'home-pile', title: '家充桩', keyword: '家充桩'),
  EquipmentCategory(id: 'accessories', title: '车载配件', keyword: '车载配件'),
  EquipmentCategory(id: 'cables', title: '充电线材', keyword: '充电线材'),
  EquipmentCategory(id: 'power-bank', title: '应急电源', keyword: '应急电源'),
];

/// 首次进入免责声明文案（iOS 版去掉小程序跳转表述）
const String equipmentTipText =
    '本页商品数据来自拼多多开放平台，均为精选带券第三方商品，'
    '价格与优惠以拼多多实际页面为准。点击商品后将跳转拼多多完成购买，敬请知晓。';

/// 骨架屏卡数量（双列 × 3 行）
const int equipmentSkeletonCount = 6;
