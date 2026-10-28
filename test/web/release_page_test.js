// 用 Node 模拟浏览器的 DOM + fetch，验证发布页 index.html 的渲染逻辑
// 数据源：GitHub Releases API（与 App 检查更新同一个接口）
const fs = require('fs');
const path = require('path');

const dir = path.resolve(__dirname, '../../release');
const html = fs.readFileSync(path.join(dir, 'index.html'), 'utf8');

// 模拟一条 GitHub Release
const release = {
  tag_name: 'v1.2.0',
  published_at: '2026-10-28T12:00:00Z',
  body: [
    '## DSH Harness v1.2.0',
    '',
    '### 更新内容',
    '',
    '<!-- notes -->',
    '- 新增扫码入口',
    '- 修复中文界面',
    '<!-- /notes -->',
    '',
    '<!-- versionCode=120 -->',
    '<!-- minAndroidVersion=7.0 -->',
  ].join('\n'),
  assets: [
    {
      name: 'dsh-harness.apk',
      size: 69096589,
      browser_download_url:
        'https://github.com/kirning/dsh-remote-android/releases/download/v1.2.0/dsh-harness.apk',
    },
  ],
};

// 极简 DOM
class El {
  constructor(tag, id) {
    this.tag = tag; this.id = id; this._text = ''; this._attrs = {}; this.children = [];
  }
  set textContent(v) { this._text = String(v); this.children = []; }
  get textContent() { return this._text; }
  set innerHTML(v) { this._html = String(v); if (v === '') this.children = []; }
  get innerHTML() { return this._html || ''; }
  setAttribute(k, v) { this._attrs[k] = v; }
  getAttribute(k) { return this._attrs[k] ?? null; }
  removeAttribute(k) { delete this._attrs[k]; }
  set href(v) { this._attrs['href'] = v; }
  get href() { return this._attrs['href'] ?? null; }
  get className() { return this._attrs['class'] || ''; }
  appendChild(child) { this.children.push(child); return child; }
}

const els = {};
for (const id of ['versionBadge','apkName','apkMeta','dlBtn','kvVersion','kvBuild','kvSize','kvReq','kvDate','hash','notes','repoLink']) {
  els[id] = new El('div', id);
}
const notesEl = new El('ul', 'notes');
els['notes'] = notesEl;
const featureEls = Array.from({length: 6}, () => new El('div'));

global.document = {
  getElementById: (id) => els[id] || null,
  querySelectorAll: (sel) => {
    if (sel === '#notes li') return notesEl.children;
    if (sel === '.kv dd') return [els.kvVersion, els.kvBuild, els.kvSize, els.kvReq, els.kvDate];
    if (sel === '.feature') return featureEls;
    return [];
  },
  createElement: (t) => new El(t),
  body: new El('body'),
};
global.window = {};

global.fetch = (url) => {
  if (String(url).includes('/releases/latest')) {
    return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(release) });
  }
  return Promise.reject(new Error('unexpected ' + url));
};

const scriptMatch = html.match(/<script>([\s\S]*?)<\/script>/);
if (!scriptMatch) { console.error('FAIL: 页面里没有找到脚本'); process.exit(1); }

try {
  eval(scriptMatch[1]);
} catch (e) {
  console.error('FAIL: 脚本执行异常', e.message);
  process.exit(1);
}

setTimeout(() => {
  const checks = [];
  const check = (name, actual, expected) => {
    const ok = String(actual).includes(String(expected));
    checks.push({ name, ok, actual, expected });
  };

  check('版本徽章', els.versionBadge.textContent, 'v1.2.0');
  check('APK 元信息含版本', els.apkMeta.textContent, '1.2.0');
  check('APK 元信息含大小', els.apkMeta.textContent, 'MB');
  check('APK 元信息含来源', els.apkMeta.textContent, 'GitHub Release');
  check('下载链接指向 Release 资产', els.dlBtn.getAttribute('href'), 'dsh-harness.apk');
  check('版本表-版本', els.kvVersion.textContent, '1.2.0');
  check('版本表-构建号来自 body 标记', els.kvBuild.textContent, '120');
  check('版本表-大小', els.kvSize.textContent, 'MB');
  check('更新日志条数', notesEl.children.length, 2);
  check('更新日志首条', notesEl.children[0]?.textContent, '新增扫码入口');
  check('更新日志次条', notesEl.children[1]?.textContent, '修复中文界面');
  check('功能卡片数', featureEls.length, 6);

  let pass = 0;
  for (const c of checks) {
    console.log(`${c.ok ? '✓' : '✗'} ${c.name}` + (c.ok ? '' : `  期望含「${c.expected}」，实际「${c.actual}」`));
    if (c.ok) pass++;
  }
  console.log(`\n${pass}/${checks.length} 项通过`);
  process.exit(pass === checks.length ? 0 : 1);
}, 300);
