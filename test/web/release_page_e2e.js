// 发布页端到端验证：用极简 DOM 模拟浏览器 + 真实 GitHub API
// 验证发布页能否正确从 GitHub Releases 读出版本、大小、下载链接与更新日志。
const fs = require('fs');
const https = require('https');

const HTML = fs.readFileSync(
  require('path').resolve(__dirname, '../../release-site/index.html'), 'utf8');
const SCRIPT = HTML.match(/<script>([\s\S]*?)<\/script>/)[1];

class El {
  constructor(id) {
    this.id = id; this._t = ''; this._h = '';
    this.children = []; this.attrs = {}; this.href = '';
  }
  set textContent(v) { this._t = String(v); }
  get textContent() { return this._t; }
  set innerHTML(v) { this._h = String(v); this.children = []; }
  get innerHTML() { return this._h; }
  setAttribute(k, v) { this.attrs[k] = v; if (k === 'href') this.href = v; }
  getAttribute(k) { return this.attrs[k] ?? null; }
  removeAttribute(k) { delete this.attrs[k]; }
  appendChild(c) { this.children.push(c); return c; }
}

const els = {};
['versionBadge', 'apkMeta', 'kvVersion', 'kvBuild', 'kvSize', 'kvDate',
 'hash', 'notes', 'dlBtn', 'repoLink'].forEach((id) => { els[id] = new El(id); });

global.document = {
  getElementById: (id) => els[id] || null,
  createElement: (tag) => new El(tag),
};

global.fetch = (url, opts) => {
  console.log('  → 请求', url.replace('https://api.github.com/repos/', 'API: '));
  return new Promise((resolve, reject) => {
    // GitHub API 强制要求 User-Agent，浏览器天然会带，这里必须显式补上。
    const req = https.get(url, {
      headers: { ...((opts && opts.headers) || {}), 'User-Agent': 'dsh-release-page-test' },
    }, (res) => {
      let d = '';
      res.on('data', (c) => { d += c; });
      res.on('end', () => {
        console.log(`  → HTTP ${res.statusCode}`);
        if (res.statusCode === 404) return reject(new Error('还没有发布过 Release'));
        if (res.statusCode !== 200) return reject(new Error('HTTP ' + res.statusCode));
        resolve({ ok: true, status: res.statusCode, json: () => Promise.resolve(JSON.parse(d)) });
      });
    });
    req.on('error', (e) => reject(e));
    req.setTimeout(20000, () => { req.destroy(); reject(new Error('超时')); });
  });
};

eval(SCRIPT);

setTimeout(() => {
  console.log('\n--- 渲染结果 ---');
  console.log('版本徽章  :', els.versionBadge.textContent);
  console.log('APK 元信息:', els.apkMeta.textContent);
  console.log('构建号    :', els.kvBuild.textContent);
  console.log('大小      :', els.kvSize.textContent);
  console.log('发布日期  :', els.kvDate.textContent);
  console.log('下载链接  :', els.dlBtn.href);
  console.log('更新日志  :');
  els.notes.children.forEach((c, i) => console.log(`   ${i + 1}. ${c.textContent}`));

  const notes = els.notes.children.length;
  const checks = [
    ['版本徽章为 v1.0.0', els.versionBadge.textContent === 'v1.0.0'],
    ['下载链接指向 .apk', els.dlBtn.href.includes('.apk')],
    ['下载链接指向 GitHub', els.dlBtn.href.includes('github.com')],
    ['构建号已解析', /^\d+$/.test(els.kvBuild.textContent)],
    ['大小已解析', /MB|KB/.test(els.kvSize.textContent)],
    ['更新日志 5 条', notes === 5],
  ];
  console.log('\n--- 断言 ---');
  checks.forEach(([name, ok]) => console.log(`  ${ok ? '✓' : '✗'} ${name}`));
  const all = checks.every(([, ok]) => ok);
  console.log(all ? '\n全部通过' : '\n存在失败项');
  process.exit(all ? 0 : 1);
}, 5000);
