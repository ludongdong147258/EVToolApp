# EV Tool

电动汽车工具 App —— 基于 Flutter 构建（仅 iOS），采用功能优先（Feature-first）架构 + Riverpod 状态管理。基础框架移植自 FishMind 项目。

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

# 格式化
dart format .

# 运行应用（API 地址通过 dart-define 注入）
flutter run --dart-define=API_BASE_URL=https://api.example.com/
```

**中国镜像**是 `pub get` 的必要条件 — 确保已设置以下环境变量：

```
PUB_HOSTED_URL=https://pub.flutter-io.cn
FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

## 架构

```
lib/
├── main.dart                # 启动：dotenv + SharedPreferences 容错 + ProviderScope overrides
├── app.dart                 # 根 ConsumerWidget：MaterialApp.router + 亮/暗主题
├── core/                    # 共享基础设施（不含功能特定代码）
│   ├── constants/           # 应用名、版本号、网络超时、API 基础 URL（dart-define）
│   ├── extensions/          # BuildContext 扩展：主题、尺寸、pop()
│   ├── network/             # Dio 客户端、ApiResult 密封类、401 刷新拦截器、信封解析
│   ├── routing/             # GoRouter + StatefulShellRoute + 认证守卫 + 路由名称
│   ├── storage/             # SharedPreferences（主题）+ Secure Storage（token，内存镜像）
│   ├── theme/               # Material 3：科技蓝绿色板、排版、亮/暗主题
│   ├── utils/               # 全局 Logger 实例
│   └── widgets/             # 共享 UI：导航栏、错误、加载、骨架屏、Toast 等
└── features/                # 功能模块（data/ + presentation/ 分层）
    ├── auth/                # 认证骨架（mock 登录，待接入 API）
    ├── home/                # 首页（占位）
    ├── charging/            # 充电（占位）
    ├── tools/               # 工具（占位）
    └── profile/             # 我的（占位，含设置/关于页）
```

## 新功能模块开发约定

1. 在 `lib/features/<name>/` 下建立 `data/models`、`data/repositories`、`presentation/pages` 结构
2. Repository 通过 `dioProvider` 发起请求，用 `safeApiCall*` 解析 `{success, data, error}` 信封
3. 路由在 `core/routing/route_names.dart` 注册路径，`app_router.dart` 挂载页面
4. 需要登录态的路由加入 `access_guard.dart` 的 protected 集合
5. freezed/json 模型编辑后运行 build_runner

## 环境变量

- `.env`：运行时密钥（gitignored），模板见 `.env.example`
- `API_BASE_URL`：编译期 dart-define 注入，默认占位 `https://api.example.com/`
