/// URL 规范化与校验工具。
class UrlUtils {
  UrlUtils._();

  /// 合法主机名：ASCII 字母数字、点、横线、下划线（兼容 IP 与常见内网域名）。
  static final RegExp _hostPattern =
      RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-._]*[a-zA-Z0-9])?$');

  /// 整串就是一个 URL（不含空白）。
  static final RegExp _wholeUrlPattern =
      RegExp(r'^https?://[^\s/?#]+(?:[/?#]\S*)?$', caseSensitive: false);

  /// 文本中出现的 http/https 地址。
  static final RegExp _httpUrlPattern =
      RegExp(r'''https?://[^\s"'<>]+''', caseSensitive: false);

  /// 文本中出现的裸 IP:端口。
  static final RegExp _bareHostPattern =
      RegExp(r'''(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?''');

  /// 把用户输入整理成可访问的地址。
  ///
  /// - 允许省略 scheme（`192.168.1.5:8080` → `http://192.168.1.5:8080`）。
  /// - 去掉首尾空白与多余斜杠。
  /// - 已带 scheme 的保持原样。
  static String normalize(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return value;

    // 去掉末尾多余的斜杠（根路径除外），避免出现 `http://x//`
    while (value.length > 1 && value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }

    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(value);
    if (!hasScheme) {
      value = 'http://$value';
    }
    return value;
  }

  /// 校验地址是否可用于 WebView 加载。
  ///
  /// 返回 null 表示合法，否则返回错误提示文案。
  static String? validate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '请输入 dsh-harness 地址';

    // 已显式写了 scheme 时，先确认协议受支持。
    final schemeMatch =
        RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*)://').firstMatch(value);
    if (schemeMatch != null) {
      final scheme = schemeMatch.group(1)!.toLowerCase();
      if (scheme != 'http' && scheme != 'https') {
        return '只支持 http / https 地址';
      }
    }

    // 补齐 scheme 之后，整串必须就是一个 URL，不能夹带空格等说明文字。
    final normalized = normalize(value);
    if (!_wholeUrlPattern.hasMatch(normalized)) {
      return '地址格式不正确，请只填写一个 http/https 地址';
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null) return '地址格式不正确';

    if (uri.host.isEmpty) return '地址缺少主机名';
    if (!_hostPattern.hasMatch(uri.host)) {
      return '主机名格式不正确';
    }
    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
      return '端口号不正确';
    }
    return null;
  }

  /// 从一段文本中提取第一个看起来像地址的片段。
  ///
  /// 扫码结果可能带有额外文案，这里尽力提取出可用地址。
  /// 提取不到时返回 null。
  static String? extractUrl(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    // 1. 整串就是地址
    if (validate(trimmed) == null) return normalize(trimmed);

    // 2. 文本里嵌着 http/https 地址
    final httpMatch = _httpUrlPattern.firstMatch(trimmed);
    if (httpMatch != null) {
      final candidate = httpMatch.group(0)!;
      if (validate(candidate) == null) return normalize(candidate);
    }

    // 3. 形如 "192.168.1.5:8080" 的裸地址
    final bareMatch = _bareHostPattern.firstMatch(trimmed);
    if (bareMatch != null) {
      final candidate = bareMatch.group(0)!;
      if (validate(candidate) == null) return normalize(candidate);
    }

    return null;
  }
}
