# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在本仓库中工作时提供指导。

## 项目概述

EV Tool（电动汽车工具 App）—— 基于 Flutter 构建的电动汽车伴侣应用，仅支持 iOS。基础框架移植自 FishMind 项目（功能优先架构 + Riverpod）。当前所有功能模块均为占位页，认证为 mock 骨架，待接入后端 API。

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

# 运行应用
flutter run --dart-define=API_BASE_URL=https://api.example.com/
```

**中国镜像**是 `pub get` 的必要条件 — 确保已设置以下环境变量：
```
PUB_HOSTED_URL=https://pub.flutter-io.cn
FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

## 架构

采用功能优先（Feature-first）架构，使用 Riverpod 进行状态管理和依赖注入。

```
lib/
├── main.dart                # 启动：dotenv + SharedPreferences 容错降级 + initSecureAuth + ProviderScope overrides
├── app.dart                 # 根 ConsumerWidget：MaterialApp.router + 亮/暗主题
├── core/                    # 共享基础设施（不含功能特定代码）
│   ├── constants/           # AppConstants：应用名、超时、API_BASE_URL（String.fromEnvironment）、resolveUrl()
│   ├── extensions/          # BuildContext 扩展：theme、textTheme、colorScheme、screenWidth/Height、pop()
│   ├── network/             # dioProvider（30s 超时、debug 自签放行）、ApiResult（freezed 密封类）、
│   │                        # api_response_parser（{success,data,error} 信封 + safeApiCall* 全量容错）、
│   │                        # ApiInterceptor（Bearer 注入 + 401 Completer 互斥刷新 + 失败 clearAuthData）
│   ├── routing/             # goRouterProvider + GoRouterRefreshStream（监听 authNotifier）+ redirect（?from= 防开放重定向）
│   │                        # + StatefulShellRoute.indexedStack（4 分支）+ access_guard（受保护路由集合）
│   ├── storage/             # LocalStorage：SharedPreferences（app_theme）+ flutter_secure_storage
│   │                        # （auth_token/refresh_token + 内存镜像 + 旧明文迁移）；provider 在 main 中 override
│   ├── theme/               # Material 3：AppColors（科技蓝绿 primaryTeal 0xFF00B8A9）、AppTypography、AppTheme
│   ├── utils/               # appLogger（logger 包全局实例）
│   └── widgets/             # 共享 UI：AppBottomNav（Material Icons）、MainShell、AppErrorWidget、AppLoading、
│                            # AppPrimaryButton、AppSearchBar、AppSectionHeader、AppTabSelector、Toast、skeleton/*
└── features/                # 功能模块
    ├── auth/                # 认证骨架：AuthState 密封类 + AuthNotifier（mock login/logout）+ LoginPage
    ├── home/                # 首页占位（shell 分支 0，'/'）
    ├── charging/            # 充电占位（shell 分支 1，'/charging'）
    ├── tools/               # 工具占位（shell 分支 2，'/tools'）
    └── profile/             # 我的占位（shell 分支 3，'/profile'，受保护路由）+ SettingsPage（主题切换）+ AboutPage
```

### 关键机制

| 机制 | 说明 |
|------|------|
| API 信封 | `{success: bool, data: T?, error: String?}`，所有请求经 `safeApiCall*` 解析，永不抛异常 |
| API 基础地址 | 编译期 `--dart-define=API_BASE_URL=...`（`AppConstants.apiBaseUrl`），默认占位 `https://api.example.com/` |
| Token 存储 | iOS Keychain（flutter_secure_storage），启动时 `initSecureAuth()` 载入内存镜像供拦截器同步读取 |
| 401 刷新 | `ApiInterceptor`：Completer 互斥，首个 401 用无拦截器的新 Dio POST `/api/auth/refresh`，并发 401 等待后重试 |
| 路由守卫 | `resolveProtectedAccess`：未登录访问 `/profile` → `/login?from=...`；auth 变化经 GoRouterRefreshStream 重跑 redirect |
| 主题持久化 | `app_theme`（SharedPreferences）→ `LocalStorage.themeMode` → MaterialApp themeMode |

## 测试

```
test/
├── app_test.dart                              # App 启动冒烟（4 Tab 渲染）
├── core/routing/access_guard_test.dart        # 路由守卫纯函数
├── core/network/api_response_parser_test.dart # 信封解析 + Dio 异常容错
└── helpers/                                   # FakeDioAdapter、createContainer
```

## 新功能模块开发约定

1. `lib/features/<name>/` 下建 `data/models`（freezed）、`data/repositories`、`presentation/pages|providers`
2. Repository 注入 `dioProvider`，返回 `ApiResult<T>`；UI 层用 switch 处理 success/failure
3. 新路由：`route_names.dart` 加路径 → `app_router.dart` 挂载；需登录的加入 `access_guard.dart` protected 集合
4. 编辑 freezed/json 注解后必须运行 build_runner
5. 共享 UI 先看 `core/widgets/` 是否已有现成组件
