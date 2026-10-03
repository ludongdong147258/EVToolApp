/// 电车改装合规查询（纯静态对照表）
///
/// 移植自 EVTool 小程序 src/lib/modificationCompliance.js。
/// 依据《机动车登记规定》（公安部令第 164 号）及 2022 年检验新规整理的
/// 常见改装项目合规等级、备案要求与风险提示。内容为通用参考，
/// 具体以当地车管所及最新法规为准，不构成法律建议。
library;

/// 风险等级（None → Low → Medium → High，页面徽章配色按此映射）
const List<String> riskLevels = ['None', 'Low', 'Medium', 'High'];

/// 合规等级分类（页面分区渲染顺序即数组顺序）
class ModCategory {
  const ModCategory({
    required this.id,
    required this.icon,
    required this.title,
    required this.desc,
  });

  final String id;
  final String icon;
  final String title;
  final String desc;
}

/// 单个改装项目
class ModificationItem {
  const ModificationItem({
    required this.id,
    required this.name,
    required this.category,
    required this.needRegister,
    required this.inspectionRisk,
    required this.policeRisk,
    required this.note,
  });

  final String id;
  final String name;

  /// 合规等级 id（legal / register / illegal）
  final String category;

  /// 是否需要备案（含具体期限说明）
  final String needRegister;

  /// 年审风险（取值见 [riskLevels]）
  final String inspectionRisk;

  /// 路检风险（取值见 [riskLevels]）
  final String policeRisk;
  final String note;
}

/// 三类合规等级（页面分区渲染顺序即数组顺序）
const List<ModCategory> modCategories = [
  ModCategory(
    id: 'legal',
    icon: 'check_circle',
    title: 'Legal',
    desc:
        'No registration needed or minimal requirements; just keep safety and plate readability intact',
  ),
  ModCategory(
    id: 'register',
    icon: 'warning',
    title: 'Legal (registration required)',
    desc:
        'Modify first, then register; failing to register in time is treated as illegal',
  ),
  ModCategory(
    id: 'illegal',
    icon: 'close',
    title: 'Illegal',
    desc:
        'Cannot be registered; will fail the annual inspection and can be penalized in roadside checks',
  ),
];

/// 常见改装项目对照表
const List<ModificationItem> modificationItems = [
  ModificationItem(
    id: 'interior',
    name: 'Interior modifications',
    category: 'legal',
    needRegister: 'No',
    inspectionRisk: 'None',
    policeRisk: 'None',
    note:
        'Seat covers, floor mats, trim panels, etc. — fine as long as vehicle structure and wiring are untouched',
  ),
  ModificationItem(
    id: 'decal',
    name: 'Small exterior decorations',
    category: 'legal',
    needRegister: 'No',
    inspectionRisk: 'Low',
    policeRisk: 'Low',
    note:
        'Decals must cover no more than 30% of the body and must not block or obscure the plate',
  ),
  ModificationItem(
    id: 'wheel-same',
    name: 'Same-spec wheel replacement',
    category: 'legal',
    needRegister: 'No',
    inspectionRisk: 'Low',
    policeRisk: 'Low',
    note:
        'Keep original size, J value and ET offset unchanged; tire spec must match the registration',
  ),
  ModificationItem(
    id: 'color-change',
    name: 'Body color change (wrap/paint)',
    category: 'register',
    needRegister: 'Yes (within 10 days of the change)',
    inspectionRisk: 'Low',
    policeRisk: 'Medium',
    note:
        'Registration requires updated registration photos; special-service color schemes (police/fire/ambulance) are prohibited',
  ),
  ModificationItem(
    id: 'body-kit',
    name: 'Exterior kits (bumpers/side skirts/spoilers)',
    category: 'register',
    needRegister: 'Yes',
    inspectionRisk: 'High',
    policeRisk: 'Medium',
    note:
        'Only items that do not affect the registered length/width/height can be registered; most wide-body kits will not pass',
  ),
  ModificationItem(
    id: 'wheel-spec',
    name: 'Changing wheel size/spec',
    category: 'register',
    needRegister: 'Depends on local policy',
    inspectionRisk: 'High',
    policeRisk: 'Medium',
    note:
        'Most regions do not allow changing wheel diameter; the annual inspection checks against factory specs',
  ),
  ModificationItem(
    id: 'battery-motor',
    name: 'Modifying battery/motor/electronics',
    category: 'illegal',
    needRegister: 'Not allowed',
    inspectionRisk: 'High',
    policeRisk: 'High',
    note:
        'Altering the battery/motor/electronics system is illegal, voids the warranty and poses a fire risk',
  ),
  ModificationItem(
    id: 'suspension',
    name: 'Suspension modifications (lift/lower)',
    category: 'illegal',
    needRegister: 'Not allowed',
    inspectionRisk: 'High',
    policeRisk: 'High',
    note:
        'Changing suspension structure or height cannot be registered and is always checked at the annual inspection',
  ),
  ModificationItem(
    id: 'lights-illegal',
    name: 'Illegal lights (strobe/added spotlights)',
    category: 'illegal',
    needRegister: 'Not allowed',
    inspectionRisk: 'High',
    policeRisk: 'High',
    note:
        'A frequent nighttime roadside-check item; unauthorized spotlights or strobe lights are penalized on the spot',
  ),
  ModificationItem(
    id: 'track-width',
    name: 'Wider track / spacer adapters',
    category: 'illegal',
    needRegister: 'Not allowed',
    inspectionRisk: 'High',
    policeRisk: 'High',
    note:
        'Changing the track width alters registered parameters — a textbook illegal modification',
  ),
];

/// 页面底部免责声明
const String modComplianceDisclaimer =
    'The information above is general reference only; specifics follow your local vehicle administration office and the latest regulations. Consult them before modifying your car.';

/// 按合规等级取改装项目（页面分区渲染用）
List<ModificationItem> getItemsByCategory(String category) =>
    modificationItems.where((item) => item.category == category).toList();
