import 'src/core/single_instance.dart';
import 'src/core/platform_support.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app/app.dart';
import 'src/services/update_service.dart';
import 'src/state/app_controller.dart';
import 'src/state/log_store.dart';
import 'src/utils/logger.dart';

// 全局互斥体，用于单实例检查

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isDesktop = PlatformSupport.isWindows ||
      PlatformSupport.isLinux ||
      PlatformSupport.isMacOS;
  if (isDesktop) {
    await windowManager.ensureInitialized();
  }

  // 检查单实例（仅 Windows）
  if (PlatformSupport.isWindows) {
    final isFirstInstance = acquireSingleInstance();
    if (!isFirstInstance) {
      // 如果已经有实例在运行，退出当前进程
      L.i('Another instance is already running. Exiting.', tag: 'main');
      exit(0);
    }
  }

  if (isDesktop) {
    const windowOptions = WindowOptions(
      size: Size(1024, 650),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // 初始化日志器
  final logStore = LogStore();
  L.init(logStore);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AppController(logStore: logStore)..init()),
        ChangeNotifierProxyProvider<AppController, LogStore>(
          create: (_) => logStore,
          update: (_, controller, __) => controller.logs,
        ),
      ],
      child: const _AppWithUpdateService(),
    ),
  );
}

class _AppWithUpdateService extends StatelessWidget {
  const _AppWithUpdateService();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    return ChangeNotifierProvider<UpdateService>.value(
      value: controller.updateService,
      child: const AppRoot(),
    );
  }
}
