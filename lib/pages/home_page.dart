import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/harness_controller.dart';
import '../models/harness_server.dart';
import '../widgets/server_card.dart';
import 'about_page.dart';
import 'add_server_page.dart';
import 'server_detail_page.dart';

/// 首页：仅展示历史记录卡片网格。
///
/// 左上角「+」进入添加服务页面，右上角可清空历史。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HarnessController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('DSH Harness'),
        leading: IconButton(
          tooltip: '添加服务',
          onPressed: _openAddPage,
          icon: const Icon(Icons.add),
        ),
        actions: [
          IconButton(
            tooltip: '关于与更新',
            onPressed: _openAboutPage,
            icon: const Icon(Icons.info_outline),
          ),
          if (controller.servers.isNotEmpty)
            IconButton(
              tooltip: '清空历史',
              onPressed: _confirmClearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: controller.loading
            ? const Center(child: CircularProgressIndicator())
            : controller.servers.isEmpty
                ? _buildEmptyState()
                : _buildCardGrid(controller.servers),
      ),
    );
  }

  /// 跳转到添加服务页面。
  Future<void> _openAddPage() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddServerPage()),
    );
  }

  /// 跳转到关于与更新页面。
  Future<void> _openAboutPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AboutPage()),
    );
  }

  Future<void> _confirmClearAll() async {
    final controller = context.read<HarnessController>();
    if (controller.servers.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空全部历史？'),
        content: Text('共 ${controller.servers.length} 条记录将被删除。'),
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
            child: const Text('全部删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await controller.clearAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('历史记录已清空')),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dns_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '还没有添加任何 dsh-harness 服务',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '点击左上角「+」扫码或输入地址添加',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardGrid(List<HarnessServer> servers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 按可用宽度自适应列数：手机竖屏 1 列，横屏/平板 2-3 列。
        final columns = constraints.maxWidth >= 720
            ? 3
            : constraints.maxWidth >= 480
                ? 2
                : 1;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 132,
          ),
          itemCount: servers.length,
          itemBuilder: (context, index) {
            final server = servers[index];
            return ServerCard(
              server: server,
              onTap: () => _openDetail(server),
              onDelete: () => _confirmDelete(server),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(HarnessServer server) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: Text('将删除「${server.displayTitle}」，删除后不可恢复。'),
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

    await context.read<HarnessController>().removeServer(server.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除「${server.displayTitle}」')),
    );
  }

  Future<void> _openDetail(HarnessServer server) async {
    // 收起键盘，避免进入详情页时输入法遮挡。
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServerDetailPage(server: server),
      ),
    );
    // 从详情页返回时 Flutter 会恢复之前的焦点，这里再收起一次键盘。
    if (mounted) FocusScope.of(context).unfocus();
  }
}
