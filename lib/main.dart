import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ffi/ffi.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app/app.dart';
import 'src/state/app_controller.dart';
import 'src/state/log_store.dart';
import 'src/utils/logger.dart';

// 全局互斥体，用于单实例检查
Mutex? _instanceMutex;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 必须添加这一行
  await windowManager.ensureInitialized();

  // 检查单实例（仅 Windows）
  if (Platform.isWindows) {
    final isFirstInstance = await _checkSingleInstance();
    if (!isFirstInstance) {
      // 如果已经有实例在运行，退出当前进程
      L.i('Another instance is already running. Exiting.', tag: 'main');
      exit(0);
    }
  }

  WindowOptions windowOptions = const WindowOptions(
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

/// 检查单实例
/// 返回 true 表示这是第一个实例，可以继续运行
/// 返回 false 表示已有实例在运行，应该退出
Future<bool> _checkSingleInstance() async {
  try {
    // 使用命名互斥体，名称基于应用标识
    const mutexName = 'Global\\OPLConfigManager_SingleInstance';
    
    // 尝试创建互斥体
    _instanceMutex = Mutex(mutexName);
    
    // 如果创建成功，说明这是第一个实例
    // 如果返回 false，说明互斥体已存在，即已有实例在运行
    final isFirstInstance = _instanceMutex!.tryWaitFor(const Duration(milliseconds: 0));
    
    if (!isFirstInstance) {
      // 已有实例在运行，尝试找到并显示已有窗口
      L.i('Found existing instance, attempting to restore window', tag: 'main');
      await _restoreExistingWindow();
      return false;
    }
    
    L.i('This is the first instance, acquiring mutex', tag: 'main');
    return true;
  } catch (e) {
    L.e('Failed to check single instance', tag: 'main', error: e);
    // 如果检查失败，允许继续运行
    return true;
  }
}

/// 恢复已有窗口
Future<void> _restoreExistingWindow() async {
  try {
    // 使用 user32.dll 的 FindWindow 和 ShowWindow API
    final findWindow = ffi.DynamicLibrary.open('user32.dll').lookupFunction<
      ffi.IntPtr Function(ffi.IntPtr, ffi.Pointer<ffi.UnsignedShort>),
      int Function(int, ffi.Pointer<ffi.UnsignedShort>)
    >('FindWindowW');
    
    final showWindow = ffi.DynamicLibrary.open('user32.dll').lookupFunction<
      ffi.IntPtr Function(ffi.IntPtr, ffi.Int32),
      int Function(int, int)
    >('ShowWindow');
    
    final setForegroundWindow = ffi.DynamicLibrary.open('user32.dll').lookupFunction<
      ffi.IntPtr Function(ffi.IntPtr),
      int Function(int)
    >('SetForegroundWindow');
    
    // 查找窗口标题
    final windowPtr = findWindow(0, 'OPL Config Manager'.toUtf16());
    
    if (windowPtr != 0) {
      // 恢复窗口
      showWindow(windowPtr, 9); // SW_RESTORE
      setForegroundWindow(windowPtr);
      L.i('Existing window restored and brought to foreground', tag: 'main');
    } else {
      L.w('Could not find existing window', tag: 'main');
    }
  } catch (e) {
    L.e('Failed to restore existing window', tag: 'main', error: e);
  }
}

// Mutex 类定义
class Mutex {
  final String _name;
  late final _mutexPtr = _createMutex(_name);
  bool _owned = false;

  Mutex(this._name) {
    _owned = _mutexPtr != 0;
  }

  bool tryWaitFor(Duration duration) {
    if (!_owned) return false;
    
    final result = _waitForSingleObject(_mutexPtr, duration.inMilliseconds);
    return result == 0; // WAIT_OBJECT_0
  }

  void release() {
    if (_owned && _mutexPtr != 0) {
      _releaseMutex(_mutexPtr);
      _owned = false;
    }
  }
}

// Windows API 绑定
int _createMutex(String name) {
  try {
    final createMutex = ffi.DynamicLibrary.open('kernel32.dll').lookupFunction<
      ffi.IntPtr Function(ffi.IntPtr, ffi.Int32, ffi.Pointer<ffi.UnsignedShort>),
      int Function(int, int, ffi.Pointer<ffi.UnsignedShort>)
    >('CreateMutexW');
    
    final namePtr = name.toUtf16();
    final result = createMutex(0, 0, namePtr);
    calloc.free(namePtr);
    return result;
  } catch (e) {
    L.e('Failed to create mutex', tag: 'main', error: e);
    return 0;
  }
}

int _waitForSingleObject(int handle, int milliseconds) {
  final waitForSingleObject = ffi.DynamicLibrary.open('kernel32.dll').lookupFunction<
    ffi.Int32 Function(ffi.IntPtr, ffi.Int32),
    int Function(int, int)
  >('WaitForSingleObject');
  
  return waitForSingleObject(handle, milliseconds);
}

void _releaseMutex(int handle) {
  final releaseMutex = ffi.DynamicLibrary.open('kernel32.dll').lookupFunction<
    ffi.IntPtr Function(ffi.IntPtr),
    int Function(int)
  >('ReleaseMutex');
  
  releaseMutex(handle);
}

// 扩展 String 以支持 UTF-16 编码
extension on String {
  ffi.Pointer<ffi.UnsignedShort> toUtf16() {
    final units = codeUnits;
    final ptr = calloc<ffi.Uint16>(units.length + 1);
    for (var i = 0; i < units.length; i++) {
      ptr.elementAt(i).value = units[i];
    }
    ptr.elementAt(units.length).value = 0;
    return ptr.cast();
  }
}

