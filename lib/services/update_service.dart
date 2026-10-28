import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../models/release_manifest.dart';

/// 检查更新的结果。
sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

/// 已是最新版本。
class UpToDateResult extends UpdateCheckResult {
  const UpToDateResult(this.currentVersion, this.currentVersionCode);

  final String currentVersion;
  final int currentVersionCode;
}

/// 发现了新版本。
class UpdateAvailableResult extends UpdateCheckResult {
  const UpdateAvailableResult({
    required this.manifest,
    required this.currentVersion,
    required this.currentVersionCode,
  });

  final ReleaseManifest manifest;
  final String currentVersion;
  final int currentVersionCode;
}

/// 检查失败（网络异常、清单格式错误等）。
class UpdateCheckFailedResult extends UpdateCheckResult {
  const UpdateCheckFailedResult(this.message);

  final String message;
}

/// 版本检查服务。
///
/// 优先从 **GitHub Releases** 读取最新版本（`releases/latest` 的 API），
/// APK 作为 Release 资产上传，用户点「立即下载」直接跳到 GitHub 下载页。
///
/// 若 GitHub 不可达，则回退到静态 `version.json`（自建服务器方案）。
class UpdateService {
  UpdateService({http.Client? client, String? repo, String? manifestUrl})
      : _client = client ?? http.Client(),
        _repo = repo ?? defaultRepo,
        _manifestUrl = manifestUrl ?? defaultManifestUrl;

  /// 默认的 GitHub 仓库（owner/repo）。
  static const String defaultRepo = String.fromEnvironment(
    'UPDATE_REPO',
    defaultValue: 'kirning/dsh-remote-android',
  );

  /// GitHub API 基础地址。
  static const String githubApiBase = 'https://api.github.com';

  /// 回退用的静态版本清单地址。
  static const String defaultManifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue: '',
  );

  /// GitHub 仓库（owner/repo）。
  final String _repo;

  /// 回退用的静态清单地址（为空表示不启用回退）。
  final String _manifestUrl;

  final http.Client _client;

  /// 从 GitHub Releases 拉取最新版本清单。
  Future<ReleaseManifest> fetchFromGitHub() async {
    final uri = Uri.parse('$githubApiBase/repos/$_repo/releases/latest');
    final response = await _client
        .get(uri, headers: _githubHeaders)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 404) {
      throw const UpdateException('该仓库还没有发布过 Release');
    }
    if (response.statusCode != 200) {
      throw UpdateException('GitHub 返回 ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const UpdateException('GitHub 返回的数据格式不正确');
    }
    return ReleaseManifest.fromGitHubRelease(decoded);
  }

  /// 从静态 version.json 拉取版本清单。
  Future<ReleaseManifest> fetchFromManifestFile() async {
    final uri = Uri.parse(_manifestUrl);
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw UpdateException('服务器返回 ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const UpdateException('版本清单格式不正确');
    }
    return ReleaseManifest.fromJson(decoded);
  }

  /// 依次尝试各个来源，返回第一个成功的结果。
  Future<ReleaseManifest> fetchManifest() async {
    final errors = <String>[];

    try {
      return await fetchFromGitHub();
    } catch (e) {
      errors.add('GitHub: $e');
    }

    if (_manifestUrl.isNotEmpty) {
      try {
        return await fetchFromManifestFile();
      } catch (e) {
        errors.add('静态清单: $e');
      }
    }

    throw UpdateException(errors.join('；'));
  }

  /// 检查是否有新版本。
  Future<UpdateCheckResult> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final manifest = await fetchManifest();
      final currentVersionCode = _parseVersionCode(info.buildNumber);

      final hasUpdate = manifest.versionCode > 0
          ? manifest.isNewerThan(currentVersionCode)
          : manifest.isNewerThanVersion(info.version);

      if (hasUpdate) {
        return UpdateAvailableResult(
          manifest: manifest,
          currentVersion: info.version,
          currentVersionCode: currentVersionCode,
        );
      }
      return UpToDateResult(info.version, currentVersionCode);
    } on UpdateException catch (e) {
      return UpdateCheckFailedResult(e.message);
    } catch (e) {
      return UpdateCheckFailedResult('检查更新失败：$e');
    }
  }

  /// 把构建号解析成整数，解析失败时按 0 处理。
  static int _parseVersionCode(String buildNumber) {
    return int.tryParse(buildNumber.trim()) ?? 0;
  }

  /// GitHub API 请求头。
  Map<String, String> get _githubHeaders => {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'DSH-Harness-Android',
      };

  void dispose() => _client.close();
}

/// 版本清单相关的自定义异常。
class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
