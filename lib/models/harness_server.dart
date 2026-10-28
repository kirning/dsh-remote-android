/// dsh-harness 服务条目模型。
///
/// 对应用户添加的一条历史记录：服务地址 + 备注 + 时间戳。
class HarnessServer {
  const HarnessServer({
    required this.id,
    required this.url,
    required this.note,
    required this.createdAt,
    this.lastVisitedAt,
  });

  /// 唯一标识（时间戳 + 随机后缀）。
  final String id;

  /// dsh-harness 的 HTTP 服务地址。
  final String url;

  /// 用户填写的备注。
  final String note;

  /// 添加时间。
  final DateTime createdAt;

  /// 最近一次打开时间（未访问过为 null）。
  final DateTime? lastVisitedAt;

  /// 展示用的标题：优先备注，无备注时退回主机名。
  String get displayTitle {
    if (note.trim().isNotEmpty) return note.trim();
    final uri = Uri.tryParse(url);
    final host = uri?.host.isNotEmpty == true ? uri!.host : null;
    return host ?? url;
  }

  /// 展示用的副标题：主机 + 端口。
  String get displaySubtitle {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }

  HarnessServer copyWith({
    String? url,
    String? note,
    DateTime? lastVisitedAt,
  }) {
    return HarnessServer(
      id: id,
      url: url ?? this.url,
      note: note ?? this.note,
      createdAt: createdAt,
      lastVisitedAt: lastVisitedAt ?? this.lastVisitedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
        'lastVisitedAt': lastVisitedAt?.toIso8601String(),
      };

  static HarnessServer fromJson(Map<String, dynamic> json) {
    return HarnessServer(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      lastVisitedAt: DateTime.tryParse(json['lastVisitedAt'] as String? ?? ''),
    );
  }

  @override
  String toString() => 'HarnessServer($id, $url, $note)';
}
