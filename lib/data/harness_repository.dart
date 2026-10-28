import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/harness_server.dart';

/// 历史添加记录的本地持久化仓库。
///
/// 数据以 JSON 数组形式存放在 SharedPreferences 中，key 为 [storageKey]。
class HarnessRepository {
  HarnessRepository({SharedPreferences? preferences})
      : _prefs = preferences;

  static const String storageKey = 'dsh_harness_servers';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _prefsAsync async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// 读取全部记录，按添加时间倒序（最新在前）。
  Future<List<HarnessServer>> loadAll() async {
    final prefs = await _prefsAsync;
    final raw = prefs.getString(storageKey);
    // 注意：必须返回可增长列表，调用方会往里 insert。
    if (raw == null || raw.isEmpty) return <HarnessServer>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <HarnessServer>[];
      final list = decoded
          .whereType<Map<String, dynamic>>()
          .map(HarnessServer.fromJson)
          .where((e) => e.id.isNotEmpty && e.url.isNotEmpty)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      // 数据损坏时直接丢弃，避免应用启动崩溃。
      return <HarnessServer>[];
    }
  }

  Future<void> _save(List<HarnessServer> servers) async {
    final prefs = await _prefsAsync;
    final encoded =
        jsonEncode(servers.map((e) => e.toJson()).toList(growable: false));
    await prefs.setString(storageKey, encoded);
  }

  /// 追加一条记录并持久化，返回落库后的对象。
  Future<HarnessServer> add(HarnessServer server) async {
    final servers = await loadAll();
    servers.insert(0, server);
    await _save(servers);
    return server;
  }

  /// 按 id 更新记录（备注/地址变更、最近访问时间）。
  Future<void> update(HarnessServer server) async {
    final servers = await loadAll();
    final index = servers.indexWhere((e) => e.id == server.id);
    if (index < 0) return;
    servers[index] = server;
    await _save(servers);
  }

  /// 按 id 删除记录，返回是否确实删掉了。
  Future<bool> remove(String id) async {
    final servers = await loadAll();
    final before = servers.length;
    final remain = servers.where((e) => e.id != id).toList();
    if (remain.length == before) return false;
    await _save(remain);
    return true;
  }

  /// 清空全部历史记录。
  Future<void> clearAll() async {
    final prefs = await _prefsAsync;
    await prefs.remove(storageKey);
  }
}
