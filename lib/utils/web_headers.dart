/// WebView 请求头配置。
///
/// dsh-harness / dsh-market 这类服务端会按请求头决定返回哪种语言的界面：
/// - `Accept-Language` 决定服务端渲染的文案语言；
/// - `User-Agent` 里的 `; wv` 标记会让部分站点切换到 WebView 专属（精简）布局。
///
/// Android WebView 默认继承系统语言（本机模拟器是 en-US），且完全不发送
/// `Accept-Language`，导致打开 dsh 服务时显示英文界面。
/// 这里统一改成中文桌面 Chrome 的 UA，并补上 `Accept-Language: zh-CN`。
class WebHeaders {
  WebHeaders._();

  /// 语言偏好，按优先级排列。
  static const String language = 'zh-CN';

  /// 去掉 `; wv` 标记的桌面 Chrome UA。
  ///
  /// 保留真实的 Chrome 版本号，避免服务端因版本过旧而降级到旧版页面。
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/133.0.0.0 Mobile Safari/537.36';

  /// 首帧加载时附带的请求头。
  ///
  /// 注意：Android WebView 的自定义 header 只作用于主文档的首个请求，
  /// 页面内后续的 XHR/fetch 请求不会带上这些头，
  /// 因此还需要配合 [languageScript] 给 fetch/XHR 补上语言头。
  static const Map<String, String> initial = {
    'Accept-Language': '$language,zh;q=0.9,en;q=0.8',
  };

  /// 注入到页面里的脚本：让后续的 fetch/XHR 也带上语言偏好，
  /// 并覆写 `navigator.language`，让前端按中文挑选文案词典。
  ///
  /// 服务端渲染已经由 [initial] 处理，这里补的是页面内的运行时部分。
  static const String languageScript = '''
(() => {
  try {
    // 覆写语言属性，前端 i18n 会读 navigator.language。
    if (!navigator.__dshLangPatched) {
      Object.defineProperty(navigator, 'language', {
        get: () => '$language',
        configurable: true,
      });
      Object.defineProperty(navigator, 'languages', {
        get: () => ['$language', 'zh', 'en'],
        configurable: true,
      });
      Object.defineProperty(navigator, '__dshLangPatched', {
        value: true,
        configurable: true,
      });
    }

    // 给 fetch 补上 Accept-Language。
    if (!window.fetch.__dshPatched) {
      const originFetch = window.fetch.bind(window);
      window.fetch = function (input, init) {
        const opts = init || {};
        opts.headers = new Headers(opts.headers || {});
        if (!opts.headers.has('Accept-Language')) {
          opts.headers.set('Accept-Language', '$language,zh;q=0.9,en;q=0.8');
        }
        return originFetch(input, opts);
      };
      window.fetch.__dshPatched = true;
    }

    // 给 XMLHttpRequest 补上 Accept-Language。
    if (!XMLHttpRequest.prototype.open.__dshPatched) {
      const originOpen = XMLHttpRequest.prototype.open;
      XMLHttpRequest.prototype.open = function (method, url, ...rest) {
        this.addEventListener('readystatechange', function () {
          if (this.readyState === 2) {
            try { this.setRequestHeader('Accept-Language', '$language,zh;q=0.9,en;q=0.8'); }
            catch (e) { /* 头已发送，忽略 */ }
          }
        });
        return originOpen.call(this, method, url, ...rest);
      };
      XMLHttpRequest.prototype.open.__dshPatched = true;
    }
  } catch (e) { /* 注入失败不影响主流程 */ }
})();
''';
}
