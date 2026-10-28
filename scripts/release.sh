#!/usr/bin/env bash
#
# 一键发布：构建 Release APK -> 计算校验值 -> 生成 version.json -> 拷贝到 release/
#
# 用法：
#   bash scripts/release.sh                                  # 用 pubspec.yaml 里的版本号
#   bash scripts/release.sh 1.1.0 2                          # 指定版本号与构建号
#   bash scripts/release.sh 1.1.0 2 "新增扫码入口" "修复中文界面"   # 指定更新日志
#
# 产物在 release/ 目录，把整个目录部署到任意静态服务器即可。
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
RELEASE_DIR="$ROOT/release"
PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.dev}"

# ---- 参数解析 ----
VERSION="${1:-}"
VERSION_CODE="${2:-}"
shift 2 2>/dev/null || true
NOTES=("$@")

if [ -z "$VERSION" ]; then
  # 从 pubspec.yaml 里读 version: 1.0.0+1
  read -r VERSION VERSION_CODE < <(grep -E '^version:' pubspec.yaml | sed -E 's/version:[[:space:]]*//; s/+[[:space:]]*/ /')
fi
VERSION_CODE="${VERSION_CODE:-1}"

if [ -z "$VERSION" ]; then
  echo "[!] 无法确定版本号，请显式传入：bash scripts/release.sh <version> <versionCode>"
  exit 1
fi

echo "==> 版本 $VERSION (build $VERSION_CODE)"

# ---- 构建 ----
echo "==> 构建 Release APK"
flutter build apk --release \
  --build-name="$VERSION" \
  --build-number="$VERSION_CODE"

APK_SRC="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
[ -f "$APK_SRC" ] || { echo "[!] 未找到 APK：$APK_SRC"; exit 1; }

# ---- 准备发布目录 ----
mkdir -p "$RELEASE_DIR"
# 文件名不带空格，避免部分下载器 / 服务器上 URL 编码出错。
APK_NAME="dsh-harness.apk"
cp -f "$APK_SRC" "$RELEASE_DIR/$APK_NAME"

SIZE_BYTES=$(stat -c%s "$RELEASE_DIR/$APK_NAME" 2>/dev/null || stat -f%z "$RELEASE_DIR/$APK_NAME")
SHA256=$(sha256sum "$RELEASE_DIR/$APK_NAME" | cut -d' ' -f1)
PUBLISHED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "==> 大小 $SIZE_BYTES 字节"
echo "==> sha256 $SHA256"

# ---- 生成版本清单 ----
# downloadUrl 用相对路径，这样把 release/ 目录部署到任何域名下都能正常工作。
NOTES_JSON=""
for note in "${NOTES[@]:-}"; do
  [ -z "$note" ] && continue
  [ -n "$NOTES_JSON" ] && NOTES_JSON="$NOTES_JSON,"
  ESCAPED=$(printf '%s' "$note" | sed 's/\\/\\\\/g; s/"/\\"/g')
  NOTES_JSON="$NOTES_JSON\"$ESCAPED\""
done
[ -z "$NOTES_JSON" ] && NOTES_JSON="\"发布 $VERSION 版本\""

cat > "$RELEASE_DIR/version.json" <<JSON
{
  "version": "$VERSION",
  "versionCode": $VERSION_CODE,
  "downloadUrl": "$APK_NAME",
  "sha256": "$SHA256",
  "sizeBytes": $SIZE_BYTES,
  "publishedAt": "$PUBLISHED_AT",
  "minAndroidVersion": "7.0",
  "notes": [$NOTES_JSON]
}
JSON

echo "==> 已生成 $RELEASE_DIR/version.json"
cat "$RELEASE_DIR/version.json"

# ---- 校验清单合法性 ----
if command -v python >/dev/null 2>&1; then
  python -c "import json,sys; json.load(open(sys.argv[1])); print('==> version.json 格式校验通过')" "$RELEASE_DIR/version.json"
fi

echo
echo "==> 完成。发布目录：$RELEASE_DIR"
ls -la "$RELEASE_DIR"
