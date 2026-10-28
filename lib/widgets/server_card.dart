import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/harness_server.dart';

/// 历史记录卡片。
///
/// 点击打开详情（WebView），右上角菜单可编辑备注或删除。
class ServerCard extends StatelessWidget {
  const ServerCard({
    super.key,
    required this.server,
    required this.onTap,
    required this.onDelete,
  });

  final HarnessServer server;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MM-dd HH:mm');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EFFB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.dns_outlined,
                      size: 20,
                      color: Color(0xFF1F6FEB),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          server.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          server.displaySubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '更多操作',
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18),
                            SizedBox(width: 8),
                            Text('删除'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Text(
                server.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule,
                      size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      server.lastVisitedAt == null
                          ? '添加于 ${dateFormat.format(server.createdAt)}'
                          : '最近访问 ${dateFormat.format(server.lastVisitedAt!)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
