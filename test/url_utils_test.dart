import 'package:flutter_test/flutter_test.dart';
import 'package:dsh_harness/utils/url_utils.dart';

void main() {
  group('UrlUtils.normalize', () {
    test('为缺少 scheme 的地址补上 http://', () {
      expect(UrlUtils.normalize('192.168.1.10:8080'),
          'http://192.168.1.10:8080');
      expect(UrlUtils.normalize('example.com'), 'http://example.com');
    });

    test('保留已有的 http/https scheme', () {
      expect(UrlUtils.normalize('http://a.com'), 'http://a.com');
      expect(UrlUtils.normalize('https://a.com/'), 'https://a.com');
    });

    test('去掉首尾空白与末尾多余斜杠', () {
      expect(UrlUtils.normalize('  http://a.com//  '), 'http://a.com');
    });
  });

  group('UrlUtils.validate', () {
    test('空地址报错', () {
      expect(UrlUtils.validate(''), isNotNull);
      expect(UrlUtils.validate('   '), isNotNull);
    });

    test('合法地址通过校验', () {
      expect(UrlUtils.validate('http://192.168.1.10:8080'), isNull);
      expect(UrlUtils.validate('192.168.1.10:8080'), isNull);
      expect(UrlUtils.validate('https://dsh.example.com'), isNull);
    });

    test('非 http/https 协议被拒绝', () {
      expect(UrlUtils.validate('ftp://a.com'), isNotNull);
      expect(UrlUtils.validate('file:///etc/passwd'), isNotNull);
    });
  });

  group('UrlUtils.extractUrl', () {
    test('从纯地址文本中提取', () {
      expect(UrlUtils.extractUrl('http://192.168.1.10:8080'),
          'http://192.168.1.10:8080');
    });

    test('从带说明文字的文本中提取地址', () {
      expect(
        UrlUtils.extractUrl('DSH Harness 服务 http://192.168.1.10:8080/x 请扫码'),
        'http://192.168.1.10:8080/x',
      );
    });

    test('提取裸 IP:端口', () {
      expect(UrlUtils.extractUrl('192.168.1.10:8080'),
          'http://192.168.1.10:8080');
    });

    test('没有地址时返回 null', () {
      expect(UrlUtils.extractUrl('只是一段文字'), isNull);
      expect(UrlUtils.extractUrl(''), isNull);
    });
  });
}
