# DSH Harness 手机端（dsh-android）

用 Flutter 写的 Android 客户端，用来管理并访问 **dsh-harness**（本身就是一个 HTTP 服务）。

## 功能

| 需求 | 实现 |
| --- | --- |
| 扫码添加 | 「添加服务」页点「扫码」调用相机识别二维码（`mobile_scanner`），识别到的地址自动回填到输入框 |
| 手输地址添加 | 「添加服务」页的「服务地址」输入框，可省略 `http://` |
| 备注 | 「备注（可选）」输入框，备注会显示在卡片标题上；详情页也能随时改 |
| 卡片布局 | 首页只有历史记录卡片网格，按屏宽自适应 1 / 2 / 3 列 |
| WebView 访问 | 点击卡片进入详情页，用内嵌 WebView（`webview_flutter`）打开该服务 |
| 删除 | 卡片右上角「⋮」→ 删除；详情页「⋮」菜单里也有删除；首页 AppBar 有「清空历史」 |

### 界面结构

- **首页**：只有卡片列表。左上角「+」进入添加页，右上角「ⓘ」进入关于页、「🗑」清空历史。
- **添加页**：扫码按钮 + 服务地址 + 备注 + 添加，保存后自动返回首页。
- **详情页**：顶栏无标题、无返回按钮，只保留右上角「⋮」菜单：
  **返回** / 刷新 / 用浏览器打开 / 编辑备注 / 删除。
  「返回」优先回退 WebView 内的历史，没有可回退层级时才退出详情页；
  系统返回手势/按键的行为与之保持一致。
- **关于与更新**：显示版本/构建号/应用 ID，并提供「检查更新」按钮。

## 发布与更新

发布页在 `release/` 目录（纯静态），App 的「检查更新」读同一份 `version.json`，
**两边共用一个数据源**。

```bash
# 一键发布：构建签名 APK + 生成 version.json
bash scripts/release.sh 1.1.0 2 "新增扫码入口" "修复中文界面"

# 部署 release/ 到任意静态服务器即可
```

打包时可用 `--dart-define` 指定清单地址：

```bash
flutter build apk --release \
  --dart-define=UPDATE_MANIFEST_URL=https://<你的域名>/version.json
```

详细说明见 [`docs/RELEASE.md`](docs/RELEASE.md)。

### 详情页还提供

- 顶部加载进度条
- 加载失败时显示「重试 / 用浏览器打开」
- 记录最近访问时间，卡片上显示「最近访问 xx-xx xx:xx」

## 中文界面（重要）

dsh-harness / dsh-market 会根据请求头决定返回哪种语言的界面。Android WebView 默认有两个问题：

1. **User-Agent 带 `; wv` 标记** —— 会被识别成内嵌 WebView，切换到精简布局
2. **不发送 `Accept-Language`，且 `navigator.language` 继承系统语言** —— 若系统是英文，界面就显示英文

`lib/utils/web_headers.dart` 统一处理：

| 手段 | 作用范围 |
| --- | --- |
| `setUserAgent()` 去掉 `; wv` | 全局，所有请求 |
| `loadRequest(headers:)` 带 `Accept-Language: zh-CN` | 主文档首帧 |
| 注入 JS 覆写 `navigator.language` / 包装 `fetch` / `XMLHttpRequest` | 页面内后续请求与前端 i18n |

刷新按钮也走 `loadRequest(headers:)` 而非 `reload()`，否则会丢掉语言头退回英文。

## 目录结构

```
lib/
├── main.dart                    # 应用入口，注入 Provider
├── theme/app_theme.dart         # 主题（Material 3）
├── models/harness_server.dart   # 服务条目模型
├── models/release_manifest.dart # 发布版本清单模型
├── data/harness_repository.dart # shared_preferences 持久化
├── controllers/harness_controller.dart  # 状态管理（增删改查）
├── services/update_service.dart  # 检查更新（拉取 version.json）
├── utils/url_utils.dart         # 地址规范化 / 校验 / 从扫码文本提取地址
├── utils/web_headers.dart       # WebView UA 与语言请求头配置
├── pages/
│   ├── home_page.dart           # 首页：卡片网格
│   ├── add_server_page.dart     # 添加服务页：扫码 + 地址 + 备注
│   ├── scan_page.dart           # 扫码页
│   ├── server_detail_page.dart  # 详情页（WebView）
│   └── about_page.dart          # 关于与更新页
└── widgets/server_card.dart     # 历史记录卡片
```

数据以 JSON 数组存在 `SharedPreferences` 的 `dsh_harness_servers` 键下。

## 环境要求

- Flutter 3.47.8 / Dart 3.13.7
- Android SDK（platform android-36、build-tools 37.0.0）
- JDK 17+（本机用 mise 装的 JDK 21）

本机已配置：

```bash
flutter config --android-sdk "d:\Android\Sdk" --jdk-dir "<jdk 路径>"
```

## 运行

```bash
flutter pub get
flutter run                     # 连真机或模拟器
flutter build apk --release     # 产物：build/app/outputs/flutter-apk/app-release.apk
```

> **注意**：本机代理隧道对 `pub.dev` / Maven 会返回 502，若 `flutter pub get` 失败，
> 先临时绕过代理再执行：
>
> ```bash
> env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY flutter pub get
> ```

## Android 配置要点

- `AndroidManifest.xml` 已声明 `INTERNET` 与 `CAMERA` 权限
- `android:usesCleartextTraffic="true"` —— dsh-harness 走 HTTP，允许明文流量
- 相机声明为可选硬件（`required="false"`），无摄像头设备也能安装
- `minSdk = 23`

## 测试

```bash
flutter analyze   # 静态分析
flutter test      # 单元测试：URL 工具 + 模型序列化
```
