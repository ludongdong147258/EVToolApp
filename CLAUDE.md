# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在本仓库中工作时提供指导。

## 项目概述

EV Tool（电车工具助手）—— 基于 Flutter 构建的电动汽车伴侣应用，仅支持 iOS。全部功能移植自微信小程序版 EVTool（`/Users/ludongdong/workspace/EVTool`，Taro/React）：充电记录、养车支出、车辆车库、年检维保备忘录、4 个省钱计算器、统计报表/年度报告、充电点位地图、附近充电站、装备导购、小票 OCR 识别、数据备份恢复。**数据全部本地存储（无后端）**，业务计算逻辑与备份 JSON 格式（v1）与小程序完全一致（双向兼容）。认证（auth）与 Dio token 基础设施为休眠代码，未挂载。

## 命令

```bash
# 安装依赖（需要中国镜像环境变量）
flutter pub get

# 运行代码生成（编辑 freezed/json 注解文件后必须执行）
dart run build_runner build --delete-conflicting-outputs

# 静态分析
flutter analyze

# 运行所有测试
flutter test

# 运行单个测试文件
flutter test test/path/to/test.dart

# 格式化
dart format .

# 运行应用（.env 复制自 .env.example，按需填 TENCENT_LBS_KEY / ZHIPU_API_KEY）
flutter run
```

**中国镜像**是 `pub get` 的必要条件 — 确保已设置以下环境变量：
```
PUB_HOSTED_URL=https://pub.flutter-io.cn
FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

**环境变量**（`.env`，gitignored）：`TENCENT_LBS_KEY(_BACKUP)` 附近充电站/逆地理（缺失优雅降级）、`ZHIPU_API_KEY` 小票 OCR（缺失隐藏入口）、`GOODS_API_BASE` 装备导购 API。

## 架构

功能优先（Feature-first）+ Riverpod。**移植铁律：`lib/core/domain/` 下的纯函数库与小程序 `src/lib/` 一一对应（文件名同名），公式与容错口径逐行一致，配套 jest 测试已逐条移植为 Dart 单测 —— 改公式前先看对应测试。**

```
lib/
├── main.dart                # 启动：dotenv + SharedPreferences 容错降级 + initSecureAuth + ProviderScope overrides
├── app.dart                 # 根 ConsumerWidget：watch themeSettingsProvider → 按 accent 构建 MaterialApp.router
├── core/                    # 共享基础设施
│   ├── constants/           # AppConstants（API_BASE_URL 编译期）、Env（.env 访问，未初始化安全返回空）
│   ├── domain/              # ★ 纯 Dart 业务库（无 Flutter 依赖），一一对应小程序 src/lib/*.js：
│   │                        #   numbers/date_utils/charge_records/maintenance_costs/annual_report/vehicles/
│   │                        #   fuel_ev_calc/peak_valley_calc/home_charger_calc/range_estimate/
│   │                        #   inspection_memo_calc/memo_reminder/export_data/backup_file/user_badges/
│   │                        #   user_profile/recent_tools/stations/charge_map/ocr_receipt/poster/theme_colors
│   │                        #   + data/（warranty_policy 11 品牌 / modification_compliance 10 项 / city_coords ~351 城）
│   ├── extensions/          # context.theme/textTheme/colorScheme/palette/screenWidth/pop()
│   ├── network/             # 休眠：dioProvider + ApiResult 信封 + 401 互斥刷新拦截器（待后端接入）
│   ├── routing/             # goRouterProvider：StatefulShellRoute 4 分支（'/','/costs','/tools','/profile'）
│   │                        # + ~18 个 push 子页（route_names.dart 为路径唯一来源）；无登录守卫
│   ├── storage/             # KeyValueStore（SharedPreferences 之上的 KV 抽象，读同步写异步，存 JSON 字符串）
│   │                        # + LocalStorage（主题模式 app_theme + 休眠的 Keychain token）
│   ├── theme/               # AppColors（EV Green 中性色 + COST_TYPE_COLORS + 圆角/动效常量）、
│   │                        # EvPalette（ThemeExtension，品牌色随 accent 注入）、AppTheme.light/dark(accent)、
│   │                        # theme_settings.dart（themeSettingsProvider：模式 + 6 套 accent，key themePreference）
│   ├── utils/               # appLogger
│   └── widgets/             # AppSheet（底弹层）/UndoBar（5s 撤销）/GradientHeroCard 系列/MonthBarChart（12 月柱）/
│                            # StackedBar/EmptyState/AppPrimaryButton/AppTabSelector/showAppToast/AppBottomNav（浮动胶囊+红点）/
│                            # MainShell/kBottomNavScrollPadding/skeleton/*
└── features/
    ├── records/             # 充电记录 tab：RecordRepository(key chargeRecords) + DraftRepository(formDraft:*)
    │                        # + recordsProvider/vehiclesProvider/memoListProvider/memoReminderProvider
    │                        # + records_page（月度 hero+最近记录+撤销）/record_add_page（表单+草稿+省市选择+OCR 入口）
    │                        # + widgets/（RecordCard、RecordDetailSheet）
    ├── vehicles/            # VehicleRepository（默认车不变式 + 改名/删除 → 记录&支出快照联动同步）+ PhotoStore
    │                        # + vehicles_page（车库 CRUD + 照片）+ VehicleAvatar
    ├── costs/               # CostRepository(key maintenanceCosts) + costsProvider/costFiltersProvider/
    │                        # costFilterIntentProvider（报表图例跨页筛选）+ cost_list_page（筛选+撤销）
    │                        # + cost_add_page + cost_report_page（综合费用统计）+ widgets/
    ├── stats/               # charge_stats_page（月份导航+CSV 导出）+ annual_report_page（12 月柱状图
    │                        # + RepaintBoundary 海报 → share_plus）+ widgets/annual_poster.dart
    ├── memos/               # MemoRepository(key inspectionMemos，按 vehicleId upsert) + inspection_memo_page
    │                        #（年检时间表/维保节点/保险状态，保存后 invalidate memoListProvider → 提醒条+红点）
    ├── tools/               # tools_page（hub：最近使用+分组）+ 4 计算器页 + estimate/tool_usage repositories
    ├── handbooks/           # modification_compliance_page + warranty_handbook_page（静态）
    ├── maps/                # apple_map_view.dart（★ apple_maps_flutter 唯一 import，插件隔离层）
    │                        # + charge_map_page（个人点位散点）
    ├── stations/            # StationRepository（腾讯 LBS：主备 key 轮换 120/121、cell 缓存 30min、
    │                        # 逆地理 10min 内存缓存）+ nearby_stations_page
    ├── equipment/           # GoodsRepository（拼多多商品+推广短链）+ equipment_page（6 类瀑布流+免责声明）
    ├── ocr/                 # OcrRepository（智谱 GLM-4V，1305 退避 + 模型回退）+ OcrEntryCard（key 缺失自隐藏）
    ├── profile/             # profile_page（用户卡+菜单+主题色）/backup_restore_page（JSON 导出导入去重）/
    │                        # user_profile_repository/about/agreement/privacy + AccentSwatch
    └── auth/                # 休眠：mock 认证骨架（LoginPage 未挂路由）
```

### 关键机制

| 机制 | 说明 |
|------|------|
| 存储契约 | 存储key 与 JSON 字段名与小程序完全一致（`chargeRecords`/`maintenanceCosts`/`vehicles`/`inspectionMemos`/`homeChargerEstimate`/`userProfile`/`themePreference`/`toolsRecentUse`/`formDraft:<page>`/`equipment_tip_dismissed`/`nearbyStationsCache`）；备份 JSON v1 双向兼容（`buildExportJson`/`parseExportJson`，photoPath 导出剥离） |
| 纯函数域层 | `core/domain/` 永不抛异常（非法输入返回 null/空）、无 Flutter 依赖；仓储（repositories）读→normalize→排序、写→校验→持久化，失败抛 `StorageException` 由页面 toast |
| 第三方隔离 | LBS / 智谱 / 拼多多各用独立**无鉴权 Dio**（`lbsDioProvider`/`ocrDioProvider`/`goodsDioProvider`），绝不带 token/401 拦截器 |
| 主题 | `themeSettingsProvider`（模式 + accentId 持久化）→ MaterialApp 重建换肤；品牌色经 `EvPalette` ThemeExtension 下发（`context.palette`），6 套 accent（green 默认/blue/orange/purple/pink/cyan）+ 深浅色 |
| 跨页联动 | 备忘到期 → `memoReminderProvider`（记录页提醒条 + 底栏工具 tab 红点，保存后 invalidate `memoListProvider`）；车辆改名/删除 → repository 级联同步记录+支出快照；报表图例点击 → `costFilterIntentProvider` + `context.go(costs)` |
| 撤销删除 | `showUndoBar`（SnackBar + action，5s）+ Notifier `remove`/`restoreAll`，连续删除累计批量恢复 |
| 照片 | `PhotoStore`：压缩存 `<appDocs>/vehicle_photos|avatars/`，模型只存**裸文件名**，读取时 existsSync 守卫回退图标 |
| 地图 | 坐标系 GCJ-02；Apple MapKit 用法全部隔离在 `apple_map_view.dart`（可替换 flutter_map 而页面不动） |

## 测试

```
test/
├── app_test.dart                      # 启动冒烟（4 Tab）
├── core/network/...                   # 休眠 API 层测试
├── unit/domain/                       # ★ 小程序 jest 测试逐条移植（~500 用例，公式数值期望一致）
├── unit/data/                         # 仓储测试（FakeKeyValueStore）：排序/不变式/去重/快照同步/缓存/key 轮换/1305 回退
├── widget/features/                   # 页面冒烟（SharedPreferences mock + 存储夹具）；地图页无 widget 测试（插件限制）
└── helpers/                           # FakeKeyValueStore、FakeDioAdapter
```

## 新功能模块开发约定

1. `lib/features/<name>/` 下建 `data/repositories`、`presentation/pages|providers|widgets`；纯计算逻辑放 `core/domain/` 并配单测
2. Repository 注入 `keyValueStoreProvider`；同步读（getRecords 形态）、异步写、脏数据 normalize 过滤
3. 新路由：`route_names.dart` 加路径 → `app_router.dart` 挂载
4. 编辑 freezed/json 注解后必须运行 build_runner
5. 共享 UI 先看 `core/widgets/`；颜色一律 `context.palette.*`（随 accent/深浅色切换），不硬编码
6. 网络请求一律独立无鉴权 Dio + `Env` 取 key + 缺 key 优雅降级
