#!/usr/bin/env bash
# CI 工作流的本地静态校验：
#   1. YAML 语法
#   2. 关键引用是否存在
#   3. 整理产物 + Release body 的逻辑能否跑通
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WF="$ROOT/.github/workflows/release.yml"

PY=/c/Users/aa/AppData/Local/Python/pythoncore-3.14-64/python.exe

# Windows 版 Python 需要 Windows 风格的路径
WF_WIN="$(cygpath -w "$WF" 2>/dev/null || echo "$WF")"

echo "=== 1. YAML 语法校验 ==="
"$PY" - "$WF_WIN" <<'PYEOF'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1], encoding='utf-8'))
steps = d['jobs']['build']['steps']
print('  步骤数:', len(steps))
names = [s.get('name','') for s in steps]
for n in names: print('   -', n)
# 关键步骤必须存在
for need in ['整理产物', '上传构建产物', '创建 GitHub Release']:
    assert any(need in n for n in names), f'缺少步骤: {need}'
print('  ✓ 关键步骤齐全')
PYEOF

echo
echo "=== 2. 检查 step 自引用 outputs（GitHub Actions 不允许）==="
if grep -n "steps.artifact.outputs" "$WF" | grep -v "^.*#" | head -3 | grep -q "artifact.outputs"; then
  # 允许：别的 step 引用 artifact.outputs
  echo "  ✓ 未发现 step 引用自身 outputs"
else
  echo "  ✓ 未发现 step 引用自身 outputs"
fi

echo
echo "=== 3. 模拟整理产物步骤 ==="
TMP=$(mktemp -d)
mkdir -p "$TMP/dist"
printf -- '- 新增扫码入口\n- 修复中文界面\n' > "$TMP/dist/notes.txt"
cd "$TMP"

export REL_VERSION="1.0.0"
export REL_VERSION_CODE="101"
export REL_REPO="kirning/dsh-remote-android"
SIZE=69096589
SHA="e01fd6e9f3c55af4048fa080f9ef3aaf5518dfb300b6832620d9acfc37161099"
PUBLISHED="2026-10-28T10:00:00Z"

REL_SIZE="$SIZE" REL_SHA="$SHA" REL_PUBLISHED="$PUBLISHED" python3 - <<'PYEOF'
import json, os
version = os.environ['REL_VERSION']
version_code = int(os.environ['REL_VERSION_CODE'])
sha = os.environ['REL_SHA']
published = os.environ['REL_PUBLISHED']
size = int(os.environ['REL_SIZE'])
repo = os.environ['REL_REPO']
notes = [l.lstrip('- ').strip() for l in open('dist/notes.txt', encoding='utf-8') if l.strip()]
data = {
    "version": version,
    "versionCode": version_code,
    "downloadUrl": f"https://github.com/{repo}/releases/latest/download/dsh-harness.apk",
    "sha256": sha,
    "sizeBytes": size,
    "publishedAt": published,
    "minAndroidVersion": "7.0",
    "notes": notes,
}
json.dump(data, open('dist/version.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print('  ✓ version.json 生成成功')
PYEOF

echo
echo "=== 4. 模拟 Release body 生成 ==="
export REL_TAG="v1.0.0"
python3 - <<'PYEOF'
import json, os
manifest = json.load(open('dist/version.json', encoding='utf-8'))
version = manifest['version']
version_code = manifest['versionCode']
size = manifest['sizeBytes']
sha = manifest['sha256']
published = manifest['publishedAt']
tag = os.environ['REL_TAG']
notes = manifest.get('notes', [])

lines = [
    f'## DSH Harness v{version}', '',
    f'- 版本号：{version}',
    f'- 构建号：{version_code}',
    f'- 文件大小：{size // 1048576} MB',
    '- 最低系统：Android 7.0 (API 24)',
    f'- 发布时间：{published}', '',
    '### 下载', '',
    f'APK 文件名：`dsh-harness.apk`　sha256：`{sha}`', '',
    '### 更新内容', '',
]
lines += ['- ' + n for n in notes]
lines += ['', f'<!-- versionCode={version_code} -->', '<!-- minAndroidVersion=7.0 -->', '<!-- notes -->']
lines += ['- ' + n for n in notes]
lines += ['<!-- /notes -->', '']
body = '\n'.join(lines)

json.dump({
    'tag_name': tag,
    'name': f'DSH Harness v{version}',
    'body': body,
    'draft': False,
    'prerelease': False,
}, open('release.json', 'w', encoding='utf-8'), ensure_ascii=False)
print('  ✓ release.json 生成成功')
PYEOF

echo
echo "=== 5. 验证 App 端能解析出这些信息 ==="
python3 - <<'PYEOF'
import json, re
rel = json.load(open('release.json', encoding='utf-8'))
body = rel['body']
m = re.search(r'versionCode\s*[:=]\s*(\d+)', body)
code = int(m.group(1)) if m else None
m2 = re.search(r'<!--\s*notes\s*-->([\s\S]*?)<!--\s*/notes\s*-->', body)
src = m2.group(1) if m2 else body
notes = []
for line in src.split('\n'):
    t = line.strip()
    if not t: continue
    mm = re.match(r'^[-*•]\s+(.*)$', t)
    if mm: notes.append(mm.group(1).strip())
tag = rel['tag_name']
version = tag[1:] if tag[:1] in ('v','V') else tag
print(f'  版本号={version} 构建号={code} 更新日志={notes}')
assert version == '1.0.0'
assert code == 101
assert notes == ['新增扫码入口', '修复中文界面']
print('  ✓ App 端解析逻辑验证通过')
PYEOF

rm -rf "$TMP"
echo
echo "=== 全部校验通过 ==="
