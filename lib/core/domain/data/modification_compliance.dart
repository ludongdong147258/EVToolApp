/// 电车改装合规查询（纯静态对照表）
///
/// 移植自 EVTool 小程序 src/lib/modificationCompliance.js。
/// 依据《机动车登记规定》（公安部令第 164 号）及 2022 年检验新规整理的
/// 常见改装项目合规等级、备案要求与风险提示。内容为通用参考，
/// 具体以当地车管所及最新法规为准，不构成法律建议。
library;

/// 风险等级（无 → 低 → 中 → 高，页面徽章配色按此映射）
const List<String> riskLevels = ['无', '低', '中', '高'];

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
    title: '合法改装',
    desc: '无需备案或基本无门槛，注意不影响安全与号牌识别',
  ),
  ModCategory(
    id: 'register',
    icon: 'warning',
    title: '合法但需备案',
    desc: '先改装后备案，逾期未备案按违法处理',
  ),
  ModCategory(
    id: 'illegal',
    icon: 'close',
    title: '违法改装',
    desc: '不允许备案，年审不过、路检可查处',
  ),
];

/// 常见改装项目对照表
const List<ModificationItem> modificationItems = [
  ModificationItem(
    id: 'interior',
    name: '内饰改装',
    category: 'legal',
    needRegister: '否',
    inspectionRisk: '无',
    policeRisk: '无',
    note: '座椅套、脚垫、内饰板等，不改动车辆结构与电路即可',
  ),
  ModificationItem(
    id: 'decal',
    name: '小型外观装饰',
    category: 'legal',
    needRegister: '否',
    inspectionRisk: '低',
    policeRisk: '低',
    note: '车贴面积不超过车身 30%，不得遮挡号牌或影响识别',
  ),
  ModificationItem(
    id: 'wheel-same',
    name: '同规格轮毂替换',
    category: 'legal',
    needRegister: '否',
    inspectionRisk: '低',
    policeRisk: '低',
    note: '保持原厂尺寸、J 值与 ET 值不变，轮胎规格与登记一致',
  ),
  ModificationItem(
    id: 'color-change',
    name: '车身改色（贴膜/喷漆）',
    category: 'register',
    needRegister: '是（改色后 10 日内）',
    inspectionRisk: '低',
    policeRisk: '中',
    note: '备案后需更换行驶证照片；特种车辆配色（警用/消防/救护）禁止使用',
  ),
  ModificationItem(
    id: 'body-kit',
    name: '外观套件（包围/侧裙/尾翼）',
    category: 'register',
    needRegister: '是',
    inspectionRisk: '高',
    policeRisk: '中',
    note: '仅不影响原车长宽高登记参数的项目方可备案，多数大包围无法通过',
  ),
  ModificationItem(
    id: 'wheel-spec',
    name: '改变轮毂规格尺寸',
    category: 'register',
    needRegister: '视当地政策',
    inspectionRisk: '高',
    policeRisk: '中',
    note: '多数地区不允许变更轮毂尺寸，年审按原厂参数核对',
  ),
  ModificationItem(
    id: 'battery-motor',
    name: '改动电池/电机/电控',
    category: 'illegal',
    needRegister: '不允许',
    inspectionRisk: '高',
    policeRisk: '高',
    note: '改变三电系统属违法改装，且丧失质保、存在起火风险',
  ),
  ModificationItem(
    id: 'suspension',
    name: '悬架改装（升高/降低）',
    category: 'illegal',
    needRegister: '不允许',
    inspectionRisk: '高',
    policeRisk: '高',
    note: '改变悬架结构或高度无法备案，年审必查',
  ),
  ModificationItem(
    id: 'lights-illegal',
    name: '非法灯光（爆闪/加装射灯）',
    category: 'illegal',
    needRegister: '不允许',
    inspectionRisk: '高',
    policeRisk: '高',
    note: '夜间路检高发项，私自加装射灯、爆闪灯直接查处',
  ),
  ModificationItem(
    id: 'track-width',
    name: '加宽轮距/加装垫片',
    category: 'illegal',
    needRegister: '不允许',
    inspectionRisk: '高',
    policeRisk: '高',
    note: '改变轮距影响行驶证登记参数，属典型违法改装',
  ),
];

/// 页面底部免责声明
const String modComplianceDisclaimer =
    '以上信息为通用参考，具体以当地车管所及最新法规为准，改装前建议先咨询当地车管部门。';

/// 按合规等级取改装项目（页面分区渲染用）
List<ModificationItem> getItemsByCategory(String category) =>
    modificationItems.where((item) => item.category == category).toList();
