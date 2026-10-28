import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/harness_controller.dart';
import 'data/harness_repository.dart';
import 'pages/home_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => HarnessController(repository: HarnessRepository())..load(),
      child: const DshHarnessApp(),
    ),
  );
}

class DshHarnessApp extends StatelessWidget {
  const DshHarnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSH Harness',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomePage(),
    );
  }
}
