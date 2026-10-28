import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dsh_harness/controllers/harness_controller.dart';
import 'package:dsh_harness/data/harness_repository.dart';
import 'package:dsh_harness/main.dart';
import 'package:dsh_harness/pages/add_server_page.dart';
import 'package:dsh_harness/pages/home_page.dart';
import 'package:dsh_harness/pages/scan_page.dart';

/// 添加服务全链路集成测试。
///
/// 相机识别这一步由 ML Kit 完成，难以在单元测试中复现；
/// 这里直接模拟「相机已识别到二维码并把内容回传给添加页」，
/// 验证后续的地址提取 → 回填 → 保存 → 卡片渲染整条链路。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const qrRaw =
      'https://18a6abfb206c93cd.dsh-market.com/pair-accept?pair=52689e8a35fcbf39626ad66332cdb7e6';

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) =>
            HarnessController(repository: HarnessRepository(preferences: prefs))
              ..load(),
        child: const DshHarnessApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 从首页点「+」进入添加页。
  Future<void> openAddPage(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.byType(AddServerPage), findsOneWidget);
  }

  /// 弹出扫码页并模拟相机识别到 [content] 后回传。
  Future<void> simulateScan(WidgetTester tester, String content) async {
    await tester.tap(find.text('扫码'));
    await tester.pumpAndSettle();

    expect(find.byType(ScanPage), findsOneWidget);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop(content);
    await tester.pumpAndSettle();
  }

  /// 读取指定标签输入框当前的文本。
  String fieldText(WidgetTester tester, String label) {
    final field = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, label),
    );
    return field.controller?.text ?? '';
  }

  testWidgets('首页只显示卡片，不显示添加表单与历史记录标题', (tester) async {
    await pumpApp(tester);

    // 首页没有添加表单
    expect(find.text('添加 dsh-harness 服务'), findsNothing);
    expect(find.widgetWithText(TextFormField, '服务地址'), findsNothing);
    // 没有「历史记录」标题
    expect(find.text('历史记录'), findsNothing);
    // 但有左上角的 + 按钮
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('点左上角 + 进入添加页并显示表单', (tester) async {
    await pumpApp(tester);

    await openAddPage(tester);

    expect(find.widgetWithText(TextFormField, '服务地址'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '备注（可选）'), findsOneWidget);
    expect(find.text('扫码'), findsOneWidget);
  });

  testWidgets('扫码识别后地址回填到输入框', (tester) async {
    await pumpApp(tester);
    await openAddPage(tester);

    await simulateScan(tester, qrRaw);

    expect(fieldText(tester, '服务地址'), qrRaw);
    expect(find.text('扫码成功，地址已填入'), findsOneWidget);
  });

  testWidgets('扫码内容带说明文字时也能提取出地址', (tester) async {
    await pumpApp(tester);
    await openAddPage(tester);

    await simulateScan(tester, 'DSH Harness 服务 $qrRaw 扫码连接');

    expect(fieldText(tester, '服务地址'), qrRaw);
  });

  testWidgets('扫码 → 填备注 → 添加 → 生成卡片并返回首页', (tester) async {
    await pumpApp(tester);
    await openAddPage(tester);

    await simulateScan(tester, qrRaw);

    await tester.enterText(
      find.widgetWithText(TextFormField, '备注（可选）'),
      'Market_pair',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    // 已返回首页
    expect(find.byType(HomePage), findsOneWidget);
    // 卡片出现，且标题是备注
    expect(find.text('Market_pair'), findsOneWidget);
    expect(find.text('18a6abfb206c93cd.dsh-market.com'), findsOneWidget);
    // 添加页的表单已销毁
    expect(find.byType(AddServerPage), findsNothing);
  });

  testWidgets('扫码内容不是地址时给出提示且不误添加', (tester) async {
    await pumpApp(tester);
    await openAddPage(tester);

    await simulateScan(tester, '只是一段普通文字');

    expect(find.text('未识别到有效地址：只是一段普通文字'), findsOneWidget);

    // 返回首页确认没有产生任何历史卡片
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('还没有添加任何 dsh-harness 服务'), findsOneWidget);
  });

  testWidgets('扫描到裸 IP:端口也能提取地址', (tester) async {
    await pumpApp(tester);
    await openAddPage(tester);

    await simulateScan(tester, '192.168.1.50:8080');

    expect(fieldText(tester, '服务地址'), 'http://192.168.1.50:8080');
  });

  testWidgets('手工输入地址同样可以添加', (tester) async {
    await pumpApp(tester);
    await openAddPage(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, '服务地址'),
      '192.168.1.50:8080',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '备注（可选）'),
      'Office_NAS',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    expect(find.text('Office_NAS'), findsOneWidget);
    expect(find.text('192.168.1.50:8080'), findsOneWidget);
  });
}
