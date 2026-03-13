import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';
import 'navigation.dart';
import '../ui/pages/home_shell.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OPL Config Manager',
      navigatorKey: rootNavigatorKey,
      themeMode: controller.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      home: HomeShell(
        bootError: controller.bootError,
        booting: controller.booting,
      ),
    );
  }
}

