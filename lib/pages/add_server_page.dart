import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/harness_controller.dart';
import '../utils/url_utils.dart';
import 'scan_page.dart';

/// 添加 dsh-harness 服务页面。
///
/// 支持两种添加方式：扫码识别地址，或直接手工输入地址。
/// 保存成功后返回上一页。
class AddServerPage extends StatefulWidget {
  const AddServerPage({super.key});

  @override
  State<AddServerPage> createState() => _AddServerPageState();
}

class _AddServerPageState extends State<AddServerPage> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() {
    _urlController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// 提交表单，把 dsh-harness 地址与备注写入历史。
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final url = UrlUtils.normalize(_urlController.text);
    final note = _noteController.text.trim();

    setState(() => _submitting = true);
    final controller = context.read<HarnessController>();
    try {
      await controller.addServer(url: url, note: note);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加失败：$e')),
      );
      return;
    }
    if (!mounted) return;

    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加：${note.isEmpty ? url : note}')),
    );
    Navigator.of(context).pop(true);
  }

  /// 打开扫码页，扫到地址后回填输入框。
  Future<void> _openScanner() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (scanned == null || !mounted) return;

    final extracted = UrlUtils.extractUrl(scanned);
    if (extracted == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('未识别到有效地址：$scanned')),
      );
      return;
    }

    _urlController.text = extracted;
    _urlController.selection =
        TextSelection.collapsed(offset: extracted.length);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('扫码成功，地址已填入')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加服务'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'dsh-harness 服务',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _openScanner,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('扫码'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '服务地址',
                          hintText: 'http://192.168.1.10:8080',
                          prefixIcon: Icon(Icons.link),
                        ),
                        validator: (value) => UrlUtils.validate(value ?? ''),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteController,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: '备注（可选）',
                          hintText: '例如：测试环境 / 办公室 NAS',
                          prefixIcon: Icon(Icons.notes),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add),
                        label: Text(_submitting ? '添加中…' : '添加'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
