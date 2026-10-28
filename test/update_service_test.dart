import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dsh_harness/models/release_manifest.dart';
import 'package:dsh_harness/services/update_service.dart';

void main() {
  group('ReleaseManifest.fromJson（静态清单）', () {
    test('解析全部字段', () {
      final manifest = ReleaseManifest.fromJson({
        'version': '1.2.0',
        'versionCode': 12,
        'downloadUrl': 'https://example.com/app.apk',
        'sha256': 'abc123',
        'sizeBytes': 123456,
        'publishedAt': '2026-10-28T10:00:00Z',
        'minAndroidVersion': '7.0',
        'notes': ['修复中文界面', '新增检查更新'],
      });

      expect(manifest.version, '1.2.0');
      expect(manifest.versionCode, 12);
      expect(manifest.downloadUrl, 'https://example.com/app.apk');
      expect(manifest.sha256, 'abc123');
      expect(manifest.sizeBytes, 123456);
      expect(manifest.publishedAt, '2026-10-28T10:00:00Z');
      expect(manifest.minAndroidVersion, '7.0');
      expect(manifest.notes.length, 2);
    });

    test('缺失字段时使用安全默认值', () {
      final manifest = ReleaseManifest.fromJson({'version': '1.0.0'});
      expect(manifest.version, '1.0.0');
      expect(manifest.versionCode, 0);
      expect(manifest.downloadUrl, '');
      expect(manifest.notes, isEmpty);
      expect(manifest.sha256, isNull);
    });
  });

  group('ReleaseManifest.fromGitHubRelease', () {
    Map<String, dynamic> releaseJson({
      String tag = 'v1.2.0',
      String body = '',
      List<Map<String, dynamic>>? assets,
    }) =>
        {
          'tag_name': tag,
          'body': body,
          'published_at': '2026-10-28T12:00:00Z',
          'assets': assets ??
              [
                {
                  'name': 'dsh-harness.apk',
                  'size': 69096589,
                  'browser_download_url':
                      'https://github.com/o/r/releases/download/v1.2.0/dsh-harness.apk',
                }
              ],
        };

    test('解析 tag、APK 资产与构建号', () {
      final manifest = ReleaseManifest.fromGitHubRelease(releaseJson(
        body: '<!-- versionCode=120 -->',
      ));

      expect(manifest.version, '1.2.0');
      expect(manifest.versionCode, 120);
      expect(manifest.downloadUrl,
          'https://github.com/o/r/releases/download/v1.2.0/dsh-harness.apk');
      expect(manifest.sizeBytes, 69096589);
      expect(manifest.publishedAt, '2026-10-28T12:00:00Z');
    });

    test('从 tag 的 +构建号 后缀读取版本号', () {
      final manifest =
          ReleaseManifest.fromGitHubRelease(releaseJson(tag: 'v1.3.0+45'));
      expect(manifest.version, '1.3.0');
      expect(manifest.versionCode, 45);
    });

    test('优先取注释区块里的更新日志', () {
      final manifest = ReleaseManifest.fromGitHubRelease(releaseJson(
        body: '''
正文里的普通段落

<!-- notes -->
- 新增扫码入口
- 修复中文界面
<!-- /notes -->
''',
      ));
      expect(manifest.notes, ['新增扫码入口', '修复中文界面']);
    });

    test('没有注释区块时从正文列表项提取', () {
      final manifest = ReleaseManifest.fromGitHubRelease(releaseJson(
        body: '### 更新内容\n\n- 第一项\n* 第二项\n',
      ));
      expect(manifest.notes, ['第一项', '第二项']);
    });

    test('读取 minAndroidVersion 标记', () {
      final manifest = ReleaseManifest.fromGitHubRelease(releaseJson(
        body: '<!-- minAndroidVersion=8.0 -->',
      ));
      expect(manifest.minAndroidVersion, '8.0');
    });

    test('没有 APK 资产时下载地址为空', () {
      final manifest = ReleaseManifest.fromGitHubRelease(
        releaseJson(assets: [
          {'name': 'source.zip', 'size': 100},
        ]),
      );
      expect(manifest.downloadUrl, '');
    });
  });

  group('版本比较', () {
    test('isNewerThan 按构建号严格比较', () {
      final manifest = ReleaseManifest(
        version: '2.0.0',
        versionCode: 20,
        downloadUrl: 'x',
      );
      expect(manifest.isNewerThan(19), isTrue);
      expect(manifest.isNewerThan(20), isFalse);
      expect(manifest.isNewerThan(21), isFalse);
    });

    test('构建号缺失时按版本号逐段比较', () {
      final manifest = ReleaseManifest(
        version: '1.2.0',
        versionCode: 0,
        downloadUrl: 'x',
      );
      expect(manifest.isNewerThanVersion('1.1.9'), isTrue);
      expect(manifest.isNewerThanVersion('1.2.0'), isFalse);
      expect(manifest.isNewerThanVersion('1.2.1'), isFalse);
      expect(manifest.isNewerThanVersion('2.0.0'), isFalse);
    });
  });

  group('UpdateService', () {
    test('从 GitHub Releases 成功拉取', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(),
            'https://api.github.com/repos/kirning/dsh-remote-android/releases/latest');
        expect(request.headers['Accept'], 'application/vnd.github+json');
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'tag_name': 'v2.0.0',
            'body': '<!-- versionCode=200 -->\n<!-- notes -->\n- 新功能\n<!-- /notes -->',
            'published_at': '2026-10-28T12:00:00Z',
            'assets': [
              {
                'name': 'dsh-harness.apk',
                'size': 100,
                'browser_download_url': 'https://example.com/a.apk',
              }
            ],
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = UpdateService(client: client);
      final manifest = await service.fetchFromGitHub();

      expect(manifest.version, '2.0.0');
      expect(manifest.versionCode, 200);
      expect(manifest.downloadUrl, 'https://example.com/a.apk');
      expect(manifest.notes, ['新功能']);
    });

    test('仓库还没发过 Release 时给出明确提示', () async {
      final client = MockClient((_) async => http.Response('{}', 404));
      final service = UpdateService(client: client);
      expect(
        () => service.fetchFromGitHub(),
        throwsA(isA<UpdateException>().having(
          (e) => e.message,
          'message',
          contains('还没有发布过 Release'),
        )),
      );
    });

    test('GitHub 不可用时回退到静态清单', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'api.github.com') {
          return http.Response('boom', 500);
        }
        return http.Response(
          jsonEncode({
            'version': '3.0.0',
            'versionCode': 30,
            'downloadUrl': 'https://example.com/static.apk',
          }),
          200,
        );
      });

      final service = UpdateService(
        client: client,
        manifestUrl: 'https://example.com/version.json',
      );
      final manifest = await service.fetchManifest();

      expect(manifest.version, '3.0.0');
      expect(manifest.versionCode, 30);
    });

    test('所有来源都失败时抛出汇总异常', () async {
      final client = MockClient((_) async => http.Response('err', 500));
      final service = UpdateService(
        client: client,
        manifestUrl: 'https://example.com/version.json',
      );
      expect(
        () => service.fetchManifest(),
        throwsA(isA<UpdateException>().having(
          (e) => e.message,
          'message',
          contains('GitHub'),
        )),
      );
    });
  });
}
