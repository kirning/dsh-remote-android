import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 扫码页：调用相机识别二维码，识别成功后把内容返回给调用方。
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.code128,
      BarcodeFormat.ean13,
    ],
  );

  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (!controller.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.resumed:
        controller.start();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        controller.stop();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes
        .map((e) => e.rawValue)
        .firstWhere((value) => value != null && value.trim().isNotEmpty,
            orElse: () => null);
    if (raw == null) return;

    _handled = true;
    _controller.stop();
    if (!mounted) return;
    Navigator.of(context).pop(raw.trim());
  }

  /// 把 mobile_scanner 的异常翻译成用户能看懂的中文提示。
  String _describe(MobileScannerException error) {
    return switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => '没有相机权限，请在系统设置中允许使用相机。',
      MobileScannerErrorCode.unsupported => '当前设备不支持扫码。',
      _ => '相机启动失败：${error.errorDetails?.message ?? error.errorCode.name}',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('扫码添加'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '手电筒',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ErrorView(message: _describe(error)),
          ),
          const _ScanOverlay(),
        ],
      ),
    );
  }
}

/// 取景框遮罩：中间镂空 + 底部提示。
class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF1F6FEB), width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            margin: const EdgeInsets.only(bottom: 40),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text(
              '将二维码放入框内即可自动识别',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  size: 56, color: Colors.white54),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('返回'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
