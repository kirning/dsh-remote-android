import 'package:flutter_test/flutter_test.dart';
import 'package:dsh_harness/models/harness_server.dart';

void main() {
  group('HarnessServer', () {
    test('JSON 序列化 / 反序列化往返一致', () {
      final server = HarnessServer(
        id: 'abc-123',
        url: 'http://192.168.1.10:8080',
        note: '测试环境',
        createdAt: DateTime(2026, 10, 28, 12, 30),
        lastVisitedAt: DateTime(2026, 10, 28, 13, 0),
      );

      final restored = HarnessServer.fromJson(server.toJson());

      expect(restored.id, server.id);
      expect(restored.url, server.url);
      expect(restored.note, server.note);
      expect(restored.createdAt, server.createdAt);
      expect(restored.lastVisitedAt, server.lastVisitedAt);
    });

    test('缺少可选字段时也能安全反序列化', () {
      final restored = HarnessServer.fromJson({'id': 'x', 'url': 'http://a.com'});
      expect(restored.note, '');
      expect(restored.lastVisitedAt, isNull);
    });

    test('有备注时标题用备注，否则退回主机名', () {
      final withNote = HarnessServer(
        id: '1',
        url: 'http://192.168.1.10:8080',
        note: '办公室 NAS',
        createdAt: DateTime.now(),
      );
      expect(withNote.displayTitle, '办公室 NAS');

      final withoutNote = HarnessServer(
        id: '2',
        url: 'http://192.168.1.10:8080',
        note: '  ',
        createdAt: DateTime.now(),
      );
      expect(withoutNote.displayTitle, '192.168.1.10');
      expect(withoutNote.displaySubtitle, '192.168.1.10:8080');
    });
  });
}
