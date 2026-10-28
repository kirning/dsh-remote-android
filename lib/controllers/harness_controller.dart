import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/harness_repository.dart';
import '../models/harness_server.dart';

/// 首页状态管理：持有历史列表并提供增删改。
class HarnessController extends ChangeNotifier {
  HarnessController({HarnessRepository? repository})
      : _repository = repository ?? HarnessRepository();

  final HarnessRepository _repository;

  List<HarnessServer> _servers = const [];
  bool _loading = true;

  /// 历史记录（最新在前）。
  List<HarnessServer> get servers => _servers;

  /// 是否仍在从本地读取首屏数据。
  bool get loading => _loading;

  Future<void> load() async {
    _servers = await _repository.loadAll();
    _loading = false;
    notifyListeners();
  }

  /// 新增一条 dsh-harness 服务记录。
  Future<HarnessServer> addServer({
    required String url,
    required String note,
  }) async {
    final server = HarnessServer(
      id: _generateId(),
      url: url.trim(),
      note: note.trim(),
      createdAt: DateTime.now(),
    );
    // 先更新内存状态（保证 UI 立即响应），再落盘。
    _servers = [server, ..._servers];
    notifyListeners();

    try {
      await _repository.add(server);
    } catch (e) {
      // 落盘失败时回滚内存状态，避免界面与实际存储不一致。
      _servers = _servers.where((e) => e.id != server.id).toList();
      notifyListeners();
      rethrow;
    }
    return server;
  }

  /// 更新备注（也允许顺带改地址）。
  Future<void> updateServer(HarnessServer server) async {
    await _repository.update(server);
    _servers = [
      for (final item in _servers)
        if (item.id == server.id) server else item,
    ];
    notifyListeners();
  }

  /// 记录一次访问时间。
  Future<void> markVisited(String id) async {
    final index = _servers.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final updated = _servers[index].copyWith(lastVisitedAt: DateTime.now());
    await _repository.update(updated);
    _servers = [..._servers]..[index] = updated;
    notifyListeners();
  }

  /// 删除一条记录。
  Future<bool> removeServer(String id) async {
    final removed = await _repository.remove(id);
    if (!removed) return false;
    _servers = _servers.where((e) => e.id != id).toList();
    notifyListeners();
    return true;
  }

  /// 清空全部历史。
  Future<void> clearAll() async {
    await _repository.clearAll();
    _servers = const [];
    notifyListeners();
  }

  /// 生成一个足够唯一且单调递增的 id。
  String _generateId() {
    final random = Random();
    final suffix =
        List.generate(6, (_) => random.nextInt(36).toRadixString(36)).join();
    return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }
}
