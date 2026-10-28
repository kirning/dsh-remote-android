import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../controllers/harness_controller.dart';
import '../models/harness_server.dart';
import '../utils/web_headers.dart';

/// 详情页：用 WebView 打开已添加的 dsh-harness 服务。
class ServerDetailPage extends StatefulWidget {
  const ServerDetailPage({super.key, required this.server});

  final HarnessServer server;

  @override
  State<ServerDetailPage> createState() => _ServerDetailPageState();
}

class _ServerDetailPageState extends State<ServerDetailPage> {
  late final WebViewController _controller;
  final TextEditingController _noteController = TextEditingController();

  int _progress = 0;
  bool _loading = true;
  String? _error;

  /// 是否允许系统返回手势直接退出详情页。
  ///
  /// WebView 内还有历史可回退时置 false，先回退 WebView；
  /// 没有历史时置 true，让系统返回手势正常退出页面。
  bool _canPop = true;

  @override
  void initState() {
    super.initState();
    _noteController.text = widget.server.note;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      // 去掉 WebView 的 `; wv` 标记并声明中文语言，
      // 否则 dsh 服务会按系统语言（en-US）返回英文界面。
      ..setUserAgent(WebHeaders.userAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _progress = progress);
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          // SPA 内部路由切换不会触发 onPageFinished，这里补一次注入。
          onUrlChange: (change) {
            _controller.runJavaScript(WebHeaders.languageScript);
            _syncCanPop();
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() => _loading = false);
            // 页面内的 fetch/XHR 不会继承首帧的自定义 header，
            // 这里补注入一次，让后续请求也带上中文语言偏好。
            _controller.runJavaScript(WebHeaders.languageScript);
            context.read<HarnessController>().markVisited(widget.server.id);
            _syncCanPop();
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            // 只关心主文档加载失败，子资源报错可以忽略。
            if (error.isForMainFrame ?? true) {
              setState(() {
                _loading = false;
                _error = error.description;
              });
            }
          },
        ),
      )
      ..loadRequest(
        Uri.parse(widget.server.url),
        headers: WebHeaders.initial,
      );
  }

  @override
  void dispose() {
    _controller.clearCache();
    _noteController.dispose();
    super.dispose();
  }

  /// 返回：优先回退 WebView 内的历史，没有可回退层级时才退出详情页。
  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// 刷新 WebView 内的可回退状态，决定系统返回手势的行为。
  Future<void> _syncCanPop() async {
    if (!mounted) return;
    final canGoBack = await _controller.canGoBack();
    if (!mounted) return;
    if (canGoBack != _canPop) {
      setState(() => _canPop = !canGoBack);
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // 用带语言头的 loadRequest 而不是 reload()，
    // 否则重新加载会丢掉 Accept-Language，界面退回英文。
    final current = await _controller.currentUrl();
    await _controller.loadRequest(
      Uri.parse(current ?? widget.server.url),
      headers: WebHeaders.initial,
    );
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.server.url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有找到可用的浏览器')),
      );
    }
  }

  Future<void> _editNote() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑备注'),
        content: TextField(
          controller: _noteController,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: '备注',
            hintText: '例如：测试环境',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.pop(ctx, _noteController.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;
    final updated = widget.server.copyWith(note: result);
    await context.read<HarnessController>().updateServer(updated);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('备注已更新')),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('删除后将无法再次通过应用访问该地址。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE5484D),
              minimumSize: const Size(88, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await context.read<HarnessController>().removeServer(widget.server.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 不显示标题与返回按钮，返回入口放在右上角菜单里。
        title: const SizedBox.shrink(),
        // AppBar 默认会在可返回时自动插入返回按钮，这里显式关掉。
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            tooltip: '更多操作',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'back':
                  _goBack();
                case 'refresh':
                  _reload();
                case 'browser':
                  _openInBrowser();
                case 'note':
                  _editNote();
                case 'delete':
                  _delete();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'back',
                child: Row(
                  children: [
                    Icon(Icons.arrow_back, size: 18),
                    SizedBox(width: 10),
                    Text('返回'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 10),
                    Text('刷新'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'browser',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new, size: 18),
                    SizedBox(width: 10),
                    Text('用浏览器打开'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'note',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('编辑备注'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18),
                    SizedBox(width: 10),
                    Text('删除'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: _progress >= 100 ? null : _progress / 100,
            minHeight: 3,
            backgroundColor: Colors.grey.shade200,
          ),
        ),
      ),
      body: PopScope(
        // 顶栏没有返回按钮，系统返回手势优先用于回退 WebView 内的历史；
        // WebView 没有可回退层级时，才让手势直接退出详情页。
        canPop: _canPop,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          await _goBack();
        },
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(),
              ),
            if (_error != null)
              _ErrorOverlay(
                message: _error!,
                onRetry: _reload,
                onOpenBrowser: _openInBrowser,
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({
    required this.message,
    required this.onRetry,
    required this.onOpenBrowser,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenBrowser;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: Color(0xFFB0BEC5)),
            const SizedBox(height: 14),
            Text(
              '页面加载失败',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenBrowser,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('用浏览器打开'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
