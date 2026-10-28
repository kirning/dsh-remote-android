import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dsh_harness/data/harness_repository.dart';
import 'package:dsh_harness/models/harness_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HarnessRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = HarnessRepository(
      preferences: await SharedPreferences.getInstance(),
    );
  });

  HarnessServer makeServer(String id, {String note = ''}) => HarnessServer(
        id: id,
        url: 'http://192.168.1.$id:8080',
        note: note,
        createdAt: DateTime(2026, 10, 28, 10, int.parse(id)),
      );

  test('首次添加到空存储不会抛不可变列表异常', () async {
    // 回归用例：loadAll() 曾返回 const []，导致 insert 抛
    // "Cannot add to an unmodifiable list"。
    final server = await repository.add(makeServer('1', note: '第一个'));
    expect(server.id, '1');

    final all = await repository.loadAll();
    expect(all.length, 1);
    expect(all.first.note, '第一个');
  });

  test('多次添加后按添加时间倒序排列', () async {
    await repository.add(makeServer('1', note: 'A'));
    await repository.add(makeServer('2', note: 'B'));
    await repository.add(makeServer('3', note: 'C'));

    final all = await repository.loadAll();
    expect(all.map((e) => e.note).toList(), ['C', 'B', 'A']);
  });

  test('删除指定记录后其余保留', () async {
    await repository.add(makeServer('1'));
    await repository.add(makeServer('2'));

    final removed = await repository.remove('1');
    expect(removed, isTrue);

    final all = await repository.loadAll();
    expect(all.length, 1);
    expect(all.first.id, '2');

    expect(await repository.remove('not-exist'), isFalse);
  });

  test('clearAll 清空全部记录', () async {
    await repository.add(makeServer('1'));
    await repository.add(makeServer('2'));

    await repository.clearAll();
    expect(await repository.loadAll(), isEmpty);
  });

  test('存储内容损坏时安全返回空列表', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(HarnessRepository.storageKey, 'not-a-json');

    expect(await repository.loadAll(), isEmpty);

    // 损坏数据后仍可正常添加
    await repository.add(makeServer('1'));
    expect((await repository.loadAll()).length, 1);
  });
}
