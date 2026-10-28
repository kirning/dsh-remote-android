import 'package:flutter_test/flutter_test.dart';

import 'package:dsh_harness/utils/web_headers.dart';

void main() {
  group('WebHeaders', () {
    test('User-Agent 不含 WebView 的 wv 标记', () {
      // `; wv` 会让站点识别出这是内嵌 WebView 并切换到精简布局。
      expect(WebHeaders.userAgent.contains('; wv'), isFalse);
      expect(WebHeaders.userAgent.contains('wv)'), isFalse);
    });

    test('User-Agent 伪装成正常移动端 Chrome', () {
      expect(WebHeaders.userAgent, startsWith('Mozilla/5.0'));
      expect(WebHeaders.userAgent, contains('Chrome/'));
      expect(WebHeaders.userAgent, contains('Mobile Safari'));
      // 不应带 Android WebView 的 Version/4.0 标记
      expect(WebHeaders.userAgent.contains('Version/4.0'), isFalse);
    });

    test('首帧请求头带 Accept-Language 且中文优先', () {
      final al = WebHeaders.initial['Accept-Language'];
      expect(al, isNotNull);
      expect(al, startsWith('zh-CN'));
      expect(al, contains('zh'));
    });

    test('注入脚本覆写 navigator.language 为中文', () {
      final script = WebHeaders.languageScript;
      expect(script.contains('navigator'), isTrue);
      expect(script.contains('zh-CN'), isTrue);
      expect(script.contains('Accept-Language'), isTrue);
      // 必须同时处理 fetch 与 XHR 两条链路
      expect(script.contains('window.fetch'), isTrue);
      expect(script.contains('XMLHttpRequest'), isTrue);
    });

    test('注入脚本幂等：重复执行不会重复包装', () {
      final script = WebHeaders.languageScript;
      expect(script.contains('__dshLangPatched'), isTrue);
      expect(script.contains('__dshPatched'), isTrue);
    });
  });
}
