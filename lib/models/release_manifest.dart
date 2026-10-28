/// 发布版本清单。
///
/// 数据来源有两种：
/// - GitHub Releases 的 `latest` release（优先），APK 作为 Release 资产上传；
/// - 静态 `version.json`（回退方案，用于自建服务器）。
///
/// 两种来源最终都归一成本模型，App 侧无需关心差异。
class ReleaseManifest {
  const ReleaseManifest({
    required this.version,
    required this.versionCode,
    required this.downloadUrl,
    this.sha256,
    this.sizeBytes,
    this.publishedAt,
    this.notes = const [],
    this.minAndroidVersion,
  });

  /// 语义化版本号，如 `1.1.0`。
  final String version;

  /// 递增的构建号，用于严格比较新旧（整数越大越新）。
  final int versionCode;

  /// APK 下载地址。
  final String downloadUrl;

  /// APK 的 sha256 校验值（可选）。
  final String? sha256;

  /// APK 文件大小（字节，可选）。
  final int? sizeBytes;

  /// 发布时间（ISO 8601，可选）。
  final String? publishedAt;

  /// 更新日志条目。
  final List<String> notes;

  /// 最低支持的 Android 版本（可选，用于提示用户）。
  final String? minAndroidVersion;

  /// 从静态 version.json 解析。
  factory ReleaseManifest.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['notes'];
    return ReleaseManifest(
      version: json['version'] as String? ?? '0.0.0',
      versionCode: (json['versionCode'] as num?)?.toInt() ?? 0,
      downloadUrl: json['downloadUrl'] as String? ?? '',
      sha256: json['sha256'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      publishedAt: json['publishedAt'] as String?,
      notes: rawNotes is List
          ? rawNotes.map((e) => e.toString()).toList(growable: false)
          : const [],
      minAndroidVersion: json['minAndroidVersion'] as String?,
    );
  }

  /// 从 GitHub Release 解析。
  ///
  /// - [version] 取 tag 名（去掉开头的 `v`）；
  /// - [versionCode] 从 tag 或 body 里找形如 `versionCode=12` 的标记，
  ///   找不到时退化为 0（此时按版本号字符串比较）；
  /// - APK 从 assets 里找 `.apk` 结尾的那一个；
  /// - 更新日志取 release body 的正文部分。
  factory ReleaseManifest.fromGitHubRelease(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String? ?? '').trim();
    final body = (json['body'] as String? ?? '').trim();

    // 优先从 body 里读结构化标记：<!-- versionCode=12 -->
    var code = _extractVersionCode(body);
    // 其次从 tag 里读：v1.1.0+12 或 v1.1.0
    code ??= _extractVersionCodeFromTag(tag);

    final assets = json['assets'];
    String? apkUrl;
    int? apkSize;
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map<String, dynamic>) continue;
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (!name.endsWith('.apk')) continue;
        apkUrl = asset['browser_download_url'] as String?;
        apkSize = (asset['size'] as num?)?.toInt();
        break;
      }
    }

    return ReleaseManifest(
      version: _stripVPrefix(tag),
      versionCode: code ?? 0,
      downloadUrl: apkUrl ?? '',
      sizeBytes: apkSize,
      publishedAt: json['published_at'] as String?,
      notes: _parseNotes(body),
      minAndroidVersion: _extractMinAndroid(body),
    );
  }

  /// 从正文里读 `versionCode=12` 形式的标记。
  static int? _extractVersionCode(String body) {
    final match = RegExp(r'versionCode\s*[:=]\s*(\d+)').firstMatch(body);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// 从 tag 里读构建号，兼容 `v1.1.0+12` 与 `v1.1.0-12`。
  static int? _extractVersionCodeFromTag(String tag) {
    final match = RegExp(r'[+\-](\d+)\s*$').firstMatch(tag);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// 去掉 tag 开头的 `v`。
  static String _stripVPrefix(String tag) {
    var value = tag.trim();
    if (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1);
    }
    // 去掉构建号后缀
    final plus = value.indexOf('+');
    if (plus > 0) value = value.substring(0, plus);
    return value;
  }

  /// 提取更新日志：取正文中第一个列表区块。
  static List<String> _parseNotes(String body) {
    if (body.isEmpty) return const [];

    // 优先读被 HTML 注释包起来的区块（Action 生成时用这个避免污染正文展示）
    final marked = RegExp(r'<!--\s*notes\s*-->([\s\S]*?)<!--\s*/notes\s*-->')
        .firstMatch(body);
    final source = marked?.group(1) ?? body;

    final notes = <String>[];
    for (final line in source.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // 匹配 "- xxx" / "* xxx" / "• xxx" 形式的列表项
      final m = RegExp(r'^[-*•]\s+(.*)$').firstMatch(trimmed);
      if (m != null) {
        notes.add(m.group(1)!.trim());
      }
    }
    return notes;
  }

  /// 提取最低 Android 版本标记。
  static String? _extractMinAndroid(String body) {
    final m =
        RegExp(r'minAndroidVersion\s*[:=]\s*"?([\d.]+)"?').firstMatch(body);
    return m?.group(1);
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'versionCode': versionCode,
        'downloadUrl': downloadUrl,
        if (sha256 != null) 'sha256': sha256,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
        if (publishedAt != null) 'publishedAt': publishedAt,
        'notes': notes,
        if (minAndroidVersion != null) 'minAndroidVersion': minAndroidVersion,
      };

  /// 与当前构建号比较，判断是否需要更新。
  bool isNewerThan(int currentVersionCode) => versionCode > currentVersionCode;

  /// 构建号缺失时的兜底比较：按版本号字符串逐段比大小。
  bool isNewerThanVersion(String currentVersion) {
    if (versionCode > 0) return false; // 调用方应优先用 isNewerThan
    final a = _versionParts(version);
    final b = _versionParts(currentVersion);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static List<int> _versionParts(String v) {
    return v
        .split(RegExp(r'[.\-+]'))
        .map((e) => int.tryParse(e) ?? 0)
        .take(3)
        .toList(growable: false);
  }
}
