import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app/app.dart';
import 'src/state/app_controller.dart';
import 'src/state/log_store.dart';
import 'src/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 必须添加这一行
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1024, 768),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  
  // 初始化日志器
  final logStore = LogStore();
  L.init(logStore);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppController(logStore: logStore)..init()),
        ChangeNotifierProxyProvider<AppController, LogStore>(
          create: (_) => logStore,
          update: (_, controller, __) => controller.logs,
        ),
      ],
      child: const AppRoot(),
    ),
  );
}

