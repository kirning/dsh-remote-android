# 发布指南

DSH Harness 的发布流程：构建签名 APK → 生成版本清单 → 部署发布页 → App 检查更新。

## 一键发布

```bash
# 用 pubspec.yaml 里的版本号
bash scripts/release.sh

# 指定版本号、构建号和更新日志
bash scripts/release.sh 1.1.0 2 "新增扫码入口" "修复中文界面"
```

脚本会依次完成：

1. `flutter build apk --release`（已开启 R8 混淆 + 资源压缩）
2. 把 APK 复制到 `release/DSH Harness.apk`
3. 计算 sha256 与文件大小
4. 生成 `release/version.json`
5. 校验 JSON 格式

产物：

```
release/
├── index.html          # 发布页
├── version.json        # 版本清单（App 检查更新用）
└── DSH Harness.apk     # 安装包
```

## 部署

`release/` 是纯静态目录，把整个目录部署到任意静态服务器即可：

```bash
# 举例：nginx
cp -r release/* /var/www/dsh-harness/

# 或用任何静态托管（GitHub Pages / 对象存储 / nginx）
```

部署后需要能访问到：

- `https://<你的域名>/index.html` —— 发布页
- `https://<你的域名>/version.json` —— 版本清单
- `https://<你的域名>/DSH%20Harness.apk` —— 安装包

## 配置 App 的检查更新地址

版本清单地址通过 `--dart-define` 在打包时指定：

```bash
flutter build apk --release \
  --dart-define=UPDATE_MANIFEST_URL=https://<你的域名>/version.json
```

不指定时使用代码里的默认值（`lib/services/update_service.dart` 的 `defaultManifestUrl`）。

> **注意**：`version.json` 里的 `downloadUrl` 建议用**相对路径**（如 `DSH Harness.apk`），
> 这样把目录部署到任何域名下都能正常工作，不用改清单内容。

## 签名

发布版使用 `android/dsh-harness-release.jks` 签名，配置在 `android/key.properties`。

- `key.properties` 与 `*.jks` 已加入 `.gitignore`，不要提交到版本库
- **换密钥会导致已安装的 App 无法覆盖升级**，务必妥善备份
- 缺少 `key.properties` 时会自动回退到 debug 签名，方便本地出包自测

当前密钥信息：

| 项 | 值 |
| --- | --- |
| keystore | `android/dsh-harness-release.jks` |
| alias | `dsh-harness` |
| store/key password | `dshharness` |
| 证书 CN | `CN=DSH Harness, OU=DSH, O=DSH, L=Shenzhen, ST=Guangdong, C=CN` |
| 证书 SHA-256 | `3bdb751e56511a6e385832611e0edb84165c7f386ca3e2b63a6827e4a672eace` |

## 版本号规则

- `version`（语义化版本，如 `1.1.0`）：展示给用户看
- `versionCode`（递增整数）：App 用它严格判断新旧

**每次发布必须递增 `versionCode`**，否则用户收不到更新提示。

在 `pubspec.yaml` 里改：

```yaml
version: 1.1.0+2
```

或者在发布脚本里直接传参覆盖。

## 发布页与 App 的联动

发布页的 `index.html` 会 `fetch('version.json')`，自动填充版本号、大小、
更新日志和 sha256。App 的「关于与更新」页面请求的是同一个 `version.json`。

也就是说 —— **发布页和 App 共用同一份数据源**，改一次清单两边都生效。

## 排查

**App 检查更新提示「服务器返回 404」**
清单地址不对，或文件没部署上去。用浏览器直接访问 `version.json` 确认。

**App 检查更新提示「当前已是最新版本」但实际有新版本**
`versionCode` 没递增。检查 `version.json` 里的 `versionCode` 是否大于已安装版本。

**下载后无法安装，提示「应用未安装」**
签名不一致 —— 新 APK 用了不同的密钥。检查 `apksigner verify --print-certs` 的输出。

**安装时提示「不允许安装未知来源应用」**
在系统设置里为浏览器/文件管理器开启安装权限。
