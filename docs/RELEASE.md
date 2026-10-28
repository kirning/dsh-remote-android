# 发布指南

DSH Harness 的发布流程：推 tag → GitHub Actions 自动构建 → 自动创建 Release → App 检查更新。

## 一、发布只需打一个 tag

```bash
# 1. 改版本号（pubspec.yaml）
#    version: 1.1.0+2

# 2. 提交并推送
git add -A && git commit -m "release: v1.1.0"
git push origin main

# 3. 打 tag 触发自动发布
git tag -a v1.1.0 -m "DSH Harness v1.1.0"
git push origin v1.1.0
```

推完 tag 后，GitHub Actions 会自动：

1. 安装 JDK 17 + Flutter 3.47.8
2. 拉依赖、跑静态检查、跑单元测试
3. 用 release keystore 签名构建 APK（开启 R8 混淆 + 资源压缩）
4. 上传 APK 到 Artifacts
5. 创建 GitHub Release，把 APK 作为资产挂上去
6. 生成 `version.json` 一并放进 Artifacts

构建完成的 Release 地址：

```
https://github.com/kirning/dsh-remote-android/releases/latest
```

## 二、更新日志

Action 优先读 `.github/RELEASE_NOTES.md` 作为更新日志，没有则用本次构建的提交信息。

```markdown
# .github/RELEASE_NOTES.md
- 新增扫码入口
- 修复中文界面
- 支持检查更新
```

## 三、签名配置（重要）

Release 用 `android/dsh-harness-release.jks` 签名，密钥以 **Secret** 形式存在仓库里。

需要在仓库 **Settings → Secrets and variables → Actions** 添加 4 个 Repository secret：

| Secret 名称 | 内容 | 如何生成 |
| --- | --- | --- |
| `ANDROID_KEYSTORE_BASE64` | keystore 文件的 base64 编码 | `base64 -w 0 android/dsh-harness-release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 | 生成密钥时设定 |
| `ANDROID_KEY_ALIAS` | 密钥别名 | 生成密钥时设定 |
| `ANDROID_KEY_PASSWORD` | 密钥密码 | 生成密钥时设定 |

本地对应 `android/key.properties`（已 gitignore）：

```properties
storeFile=dsh-harness-release.jks
storePassword=dshharness
keyAlias=dsh-harness
keyPassword=dshharness
```

> **没有配置 Secret 时，CI 会用 debug 签名构建**（会打印警告）。
> 这样能保证流水线始终跑通，但产出的 APK 无法覆盖升级正式版。

> **换密钥会导致已安装的 App 无法覆盖升级**，务必妥善备份 `.jks` 文件。

当前密钥信息：

| 项 | 值 |
| --- | --- |
| alias | `dsh-harness` |
| store/key password | `dshharness` |
| 证书 CN | `CN=DSH Harness, OU=DSH, O=DSH, L=Shenzhen, ST=Guangdong, C=CN` |
| 证书 SHA-256 | `3bdb751e56511a6e385832611e0edb84165c7f386ca3e2b63a6827e4a672eace` |

## 四、App 端检查更新

App 的「关于与更新」页面会请求：

```
GET https://api.github.com/repos/kirning/dsh-remote-android/releases/latest
```

从返回的 Release 里解析：

- **版本号** —— 取 `tag_name`（去掉 `v` 前缀）
- **构建号** —— 从 body 里的 `<!-- versionCode=123 -->` 标记读取
- **更新日志** —— 从 body 里的 `<!-- notes --> ... <!-- /notes -->` 区块读取
- **下载地址** —— assets 里 `.apk` 结尾的那一个

若 GitHub 不可达，会回退到静态 `version.json`（自建服务器方案），地址用
`--dart-define=UPDATE_MANIFEST_URL=...` 指定。

### 本地出包时指定仓库

```bash
flutter build apk --release \
  --dart-define=UPDATE_REPO=kirning/dsh-remote-android
```

不指定时默认就是 `kirning/dsh-remote-android`。

## 五、发布页

`release/index.html` 是产品发布页，同样从 GitHub Releases API 取数据，
所以**发布页和 App 看到的数据永远一致**。

部署方式：把 `release/` 目录传到任意静态服务器，或用 GitHub Pages。

## 六、版本号规则

| 字段 | 用途 | 谁来定 |
| --- | --- | --- |
| `version` | 展示给用户的版本号 | tag 名（`v1.1.0` → `1.1.0`） |
| `versionCode` | 严格比较新旧 | CI 自动生成：`run_number * 100 + pubspec 里的号` |

**构建号每次发布都会严格递增**，用户一定能收到更新提示。

## 七、排查

**Action 在「创建 GitHub Release」这一步失败**
看 run 的日志。当前实现直接调 REST API，失败时会打印响应体（含具体错误）。

**App 提示「该仓库还没有发布过 Release」**
仓库里确实还没发过 Release。打 tag 触发一次即可。

**App 提示「当前已是最新版本」但实际有新版本**
构建号没递增。检查 Release body 里的 `<!-- versionCode=... -->` 是否存在。

**下载后无法安装，提示「应用未安装」**
签名不一致。CI 用的 Secret 里配的 keystore 和本地不是同一个。
用 `apksigner verify --print-certs` 比对证书 SHA-256。

**改了 workflow 后整个 job 都不显示**
YAML 语法错误。可以用 Python 的 yaml 模块本地校验：

```bash
python -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"
```

## 八、本地发布脚本（不走 CI）

想在本机出包并生成静态发布页时用：

```bash
bash scripts/release.sh 1.1.0 2 "新增扫码入口" "修复中文界面"
```

产物在 `release/` 目录，把整个目录传到静态服务器即可。
