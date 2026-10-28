import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/release_manifest.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// 关于与更新页面。
///
/// 展示当前版本信息，并提供「检查更新」入口。
class AboutPage extends StatefulWidget {
  const AboutPage({super.key, this.updateService});

  final UpdateService? updateService;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late final UpdateService _updateService;
  PackageInfo? _info;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _updateService = widget.updateService ?? UpdateService();
    _loadInfo();
  }

  @override
  void dispose() {
    if (widget.updateService == null) _updateService.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _info = info);
  }

  /// 检查更新并给出反馈。
  Future<void> _checkForUpdate() async {
    setState(() => _checking = true);
    final result = await _updateService.check();
    if (!mounted) return;
    setState(() => _checking = false);

    switch (result) {
      case UpToDateResult(:final currentVersion):
        _showMessage('当前已是最新版本 $currentVersion');
      case UpdateAvailableResult(:final manifest):
        await _showUpdateDialog(manifest);
      case UpdateCheckFailedResult(:final message):
        _showMessage(message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 弹出版本更新对话框。
  Future<void> _showUpdateDialog(ReleaseManifest manifest) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('发现新版本 ${manifest.version}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本：${_info?.version ?? '-'}'),
            const SizedBox(height: 12),
            if (manifest.notes.isNotEmpty) ...[
              const Text('更新内容：'),
              const SizedBox(height: 6),
              ...manifest.notes.map(
                (n) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('· $n'),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后再说'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _download(manifest.downloadUrl);
            },
            icon: const Icon(Icons.download),
            label: const Text('立即下载'),
          ),
        ],
      ),
    );
  }

  Future<void> _download(String url) async {
    if (url.isEmpty) {
      _showMessage('下载地址无效');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage('无法打开下载地址');
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;

    return Scaffold(
      appBar: AppBar(
        title: const Text('关于与更新'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EFFB),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.dns_outlined,
                      size: 38,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'DSH Harness',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'dsh-harness 手机客户端',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 18),
                  _InfoRow(label: '版本', value: info?.version ?? '-'),
                  _InfoRow(
                    label: '构建号',
                    value: info?.buildNumber ?? '-',
                  ),
                  _InfoRow(
                    label: '应用 ID',
                    value: info?.packageName ?? '-',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '版本更新',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '检查是否有新版本发布，有则可直接下载安装。',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _checking ? null : _checkForUpdate,
                    icon: _checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update_alt),
                    label: Text(_checking ? '检查中…' : '检查更新'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 一行「标签 - 值」信息。
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
