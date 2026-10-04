import '../core/platform_support.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import '../state/app_controller.dart';
import '../utils/logger.dart';
import 'navigation.dart';
import '../ui/pages/home_shell.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WindowListener {
  final SystemTray _systemTray = SystemTray();
  bool _isTrayInitialized = false;
  AppController? _trayController;
  bool? _lastTrayCoreState;
  Future<void> _trayUpdates = Future<void>.value();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<AppController>();
    if (!identical(controller, _trayController)) {
      _trayController?.removeListener(_syncTrayMenu);
      _trayController = controller;
      controller.addListener(_syncTrayMenu);
    }
    _syncTrayMenu();
  }

  void _syncTrayMenu() {
    if (!mounted || !_isTrayInitialized) return;
    final running = _trayController?.coreRunning ?? false;
    if (running == _lastTrayCoreState) return;
    _lastTrayCoreState = running;
    _trayUpdates = _trayUpdates.then((_) async {
      if (mounted && _isTrayInitialized) await _updateTrayMenu(running);
    }).catchError((Object error) {
      L.e('Failed to update tray menu', tag: 'app', error: error);
    });
  }

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      _initPreventClose();

      if (PlatformSupport.isWindows) {
        _initTrayIcon();
      }
    }
  }

  bool get _isDesktop =>
      PlatformSupport.isWindows ||
      PlatformSupport.isLinux ||
      PlatformSupport.isMacOS;

  void _initTrayEventHandler() {
    // 注册托盘事件处理器
    _systemTray.registerSystemTrayEventHandler((eventName) async {
      L.d('tray event: $eventName', tag: 'app');
      if (eventName == kSystemTrayEventClick) {
        // 左键点击显示窗口
        _showWindow();
      } else if (eventName == kSystemTrayEventRightClick) {
        // Windows 上右键点击显示菜单
        await _systemTray.popUpContextMenu();
      }
    });
  }

  void _handleTrayAction(String action) async {
    L.d('tray action: $action', tag: 'app');

    // 确保获取最新的 controller
    if (!mounted) return;
    final controller = Provider.of<AppController>(context, listen: false);

    switch (action) {
      case 'show':
        await _showWindow();
        break;
      case 'toggle_core':
        if (controller.coreRunning) {
          await controller.stopCore();
        } else {
          await controller.startCore();
        }
        // 延迟更新菜单以确保状态已更新
        await Future.delayed(const Duration(milliseconds: 200));
        await _updateTrayMenu(controller.coreRunning);
        break;
      case 'exit':
        await _handleAppExit();
        break;
    }
  }

  Future<void> _initPreventClose() async {
    await windowManager.setPreventClose(true);
    L.d('prevent close enabled', tag: 'app');
  }

  @override
  void onWindowClose() async {
    L.d('window close event detected', tag: 'app');

    // 使用 MaterialApp 的 navigator key 获取 context 来显示对话框
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null) {
      L.w('navigator context not available, exiting', tag: 'app');
      await _handleAppExit();
      return;
    }

    final controller =
        Provider.of<AppController>(navigatorContext, listen: false);
    await _handleWindowClose(navigatorContext, controller);
  }

  @override
  void dispose() {
    _trayController?.removeListener(_syncTrayMenu);
    if (_isDesktop) {
      windowManager.removeListener(this);
      if (PlatformSupport.isWindows && _isTrayInitialized) {
        _systemTray.destroy();
      }
    }
    super.dispose();
  }

  Future<void> _initTrayIcon() async {
    if (_isTrayInitialized) return;

    try {
      // Initialize system tray
      await _systemTray.initSystemTray(
        title: 'OPL联机工具',
        iconPath: 'assets/icons/icon.ico',
      );

      // Create menu with click handlers
      final menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
          label: '显示窗口',
          onClicked: (menuItem) async {
            L.d('tray menu clicked: 显示窗口', tag: 'app');
            _handleTrayAction('show');
          },
        ),
        MenuItemLabel(
          label: '启动核心',
          onClicked: (menuItem) async {
            L.d('tray menu clicked: 启动核心', tag: 'app');
            _handleTrayAction('toggle_core');
          },
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: '关闭',
          onClicked: (menuItem) async {
            L.d('tray menu clicked: 关闭', tag: 'app');
            _handleTrayAction('exit');
          },
        ),
      ]);

      await _systemTray.setContextMenu(menu);

      // 注册事件处理器
      _initTrayEventHandler();

      _isTrayInitialized = true;
      _syncTrayMenu();

      L.i('tray icon initialized', tag: 'app');
    } catch (e) {
      L.e('failed to init tray', tag: 'app', error: e);
    }
  }

  Future<void> _updateTrayMenu(bool coreRunning) async {
    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: '显示窗口',
        onClicked: (menuItem) async {
          L.d('tray menu clicked: 显示窗口', tag: 'app');
          _handleTrayAction('show');
        },
      ),
      MenuItemLabel(
        label: coreRunning ? '关闭核心' : '启动核心',
        onClicked: (menuItem) async {
          L.d('tray menu clicked: ${coreRunning ? '关闭核心' : '启动核心'}',
              tag: 'app');
          _handleTrayAction('toggle_core');
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: '关闭',
        onClicked: (menuItem) async {
          L.d('tray menu clicked: 关闭', tag: 'app');
          _handleTrayAction('exit');
        },
      ),
    ]);

    await _systemTray.setContextMenu(menu);
  }

  Future<void> _showWindow() async {
    if (PlatformSupport.isWindows) {
      // Restore window from minimized state
      await windowManager.restore();
      await windowManager.focus();
      await windowManager.show();
    }
  }

  Future<void> _handleAppExit() async {
    final controller = Provider.of<AppController>(context, listen: false);

    // Stop EasyTier if running
    if (controller.easyTierService.isRunning) {
      await controller.easyTierService.stop();
    }

    // Stop core if running
    if (controller.coreRunning) {
      await controller.stopCore();
      // Give it a moment to ensure the process is killed
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Only exit on desktop platforms
    if (_isDesktop) {
      if (PlatformSupport.isWindows && _isTrayInitialized) {
        _systemTray.destroy();
      }
      windowManager.removeListener(this);
      // Destroy window
      await windowManager.destroy();
      // Exit app
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<AppController>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OPL联机工具',
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

  Future<void> _minimizeToTray() async {
    L.d('minimizing to tray', tag: 'app');
    // 使用 window_manager 隐藏窗口而不是最小化
    await windowManager.hide();
  }

  Future<void> _handleWindowClose(
      BuildContext context, AppController controller) async {
    L.d('handling window close, runInBackground: ${controller.settings.runInBackground}, askBeforeMinimize: ${controller.settings.askBeforeMinimize}',
        tag: 'app');

    if (!PlatformSupport.isWindows) {
      await _handleAppExit();
      return;
    }

    // Check if user has already made a choice
    final runInBackground = controller.settings.runInBackground;
    final askBeforeMinimize = controller.settings.askBeforeMinimize;

    // 如果开启了询问，先询问用户
    if (askBeforeMinimize) {
      // Show dialog to ask user
      L.d('showing close dialog', tag: 'app');
      final result = await _showBackgroundDialog(context);

      L.d('dialog result: $result', tag: 'app');

      if (result == null) {
        // User cancelled, do nothing (window stays open)
        L.d('user cancelled close', tag: 'app');
        return;
      }

      final choice = result.$1;
      final shouldAskAgain = result.$2;

      if (choice) {
        // User chose to run in background
        L.d('user chose background run, askAgain: $shouldAskAgain', tag: 'app');
        await controller.updateSettings(controller.settings.copyWith(
          runInBackground: true,
          askBeforeMinimize: shouldAskAgain,
        ));
        await _minimizeToTray();
      } else {
        // User chose to exit
        L.d('user chose to exit, askAgain: $shouldAskAgain', tag: 'app');
        await controller.updateSettings(controller.settings.copyWith(
          runInBackground: false,
          askBeforeMinimize: shouldAskAgain,
        ));
        await _handleAppExit();
      }
    } else {
      // 不询问，根据 runInBackground 设置执行
      if (runInBackground) {
        // User chose to run in background, just hide window
        L.d('minimizing to tray (user preference, no ask)', tag: 'app');
        await _minimizeToTray();
      } else {
        // Don't ask, just exit
        L.d('exiting without asking (askBeforeMinimize is false)', tag: 'app');
        await _handleAppExit();
      }
    }
  }

  Future<(bool, bool)?> _showBackgroundDialog(BuildContext context) async {
    // 从配置文件中读取当前的 askBeforeMinimize 值
    final controller = Provider.of<AppController>(context, listen: false);
    bool askAgain = controller.settings.askBeforeMinimize; // 默认使用配置文件中的值

    try {
      return showDialog<(bool, bool)>(
        context: context,
        barrierDismissible: false, // 防止点击外部关闭
        useRootNavigator: true, // 使用 root navigator
        builder: (_) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('关闭应用'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('是否将应用保留在后台运行？'),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('下次关闭时再次询问'),
                    subtitle: const Text('取消勾选后，将直接按本次选择执行'),
                    value: askAgain,
                    onChanged: (value) {
                      setDialogState(() {
                        askAgain = value ?? true;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(null); // 取消，返回 null
                  },
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop((false, askAgain)); // 选择"否"，完全关闭
                  },
                  child: const Text('否，完全关闭'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop((true, askAgain)); // 选择"是"，后台运行
                  },
                  child: const Text('是，后台运行'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      L.e('error showing dialog', tag: 'app', error: e);
      // 如果对话框显示失败，直接返回 false 退出
      return null;
    }
  }
}
