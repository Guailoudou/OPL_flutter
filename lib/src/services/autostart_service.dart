import 'package:path/path.dart' as p;
import '../core/platform_support.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

class AutoStartService {
  static const String _appName = 'OPL';

  /// 检查是否已设置开机自启动
  Future<bool> isEnabled() async {
    if (!kIsWeb && PlatformSupport.isWindows) {
      return await _checkWindowsRegistry();
    } else if (!kIsWeb && PlatformSupport.isLinux) {
      return await _checkLinuxAutostart();
    } else if (!kIsWeb && PlatformSupport.isMacOS) {
      return await _checkMacOSLoginItem();
    }
    return false;
  }

  /// 启用开机自启动
  Future<void> enable() async {
    try {
      if (!kIsWeb && PlatformSupport.isWindows) {
        await _enableWindowsRegistry();
      } else if (!kIsWeb && PlatformSupport.isLinux) {
        await _enableLinuxAutostart();
      } else if (!kIsWeb && PlatformSupport.isMacOS) {
        await _enableMacOSLoginItem();
      }
      L.i('开机自启动已启用', tag: 'AutoStart');
    } catch (e) {
      L.e('启用开机自启动失败: $e', tag: 'AutoStart');
      rethrow;
    }
  }

  /// 禁用开机自启动
  Future<void> disable() async {
    try {
      if (!kIsWeb && PlatformSupport.isWindows) {
        await _disableWindowsRegistry();
      } else if (!kIsWeb && PlatformSupport.isLinux) {
        await _disableLinuxAutostart();
      } else if (!kIsWeb && PlatformSupport.isMacOS) {
        await _disableMacOSLoginItem();
      }
      L.i('开机自启动已禁用', tag: 'AutoStart');
    } catch (e) {
      L.e('禁用开机自启动失败: $e', tag: 'AutoStart');
      rethrow;
    }
  }

  /// Windows: 检查注册表
  Future<bool> _checkWindowsRegistry() async {
    try {
      final result = await _checkedRun(
        'reg',
        [
          'query',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
          '/v',
          _appName
        ],
      );
      return result.exitCode == 0;
    } catch (e) {
      L.e('检查 Windows 注册表失败: $e', tag: 'AutoStart');
      return false;
    }
  }

  /// Windows: 启用注册表
  Future<void> _enableWindowsRegistry() async {
    final exePath = Platform.resolvedExecutable;
    await _checkedRun(
      'reg',
      [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
        '/v',
        _appName,
        '/d',
        '"$exePath"',
        '/f'
      ],
    );
  }

  /// Windows: 禁用注册表
  Future<void> _disableWindowsRegistry() async {
    await _checkedRun(
      'reg',
      [
        'delete',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
        '/v',
        _appName,
        '/f'
      ],
    );
  }

  /// Linux: 检查 autostart 文件
  Future<bool> _checkLinuxAutostart() async {
    try {
      final home = Platform.environment['HOME'] ?? '';
      final desktopFile = File('$home/.config/autostart/$_appName.desktop');
      return await desktopFile.exists();
    } catch (e) {
      L.e('检查 Linux autostart 失败: $e', tag: 'AutoStart');
      return false;
    }
  }

  /// Linux: 启用 autostart
  Future<void> _enableLinuxAutostart() async {
    final home = Platform.environment['HOME'] ?? '';
    final autostartDir = Directory('$home/.config/autostart');
    if (!await autostartDir.exists()) {
      await autostartDir.create(recursive: true);
    }

    final desktopFile = File('$home/.config/autostart/$_appName.desktop');
    final exePath = Platform.resolvedExecutable;
    final content = '''[Desktop Entry]
Type=Application
Name=$_appName
Exec="$exePath"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
''';
    await desktopFile.writeAsString(content);
  }

  /// Linux: 禁用 autostart
  Future<void> _disableLinuxAutostart() async {
    final home = Platform.environment['HOME'] ?? '';
    final desktopFile = File('$home/.config/autostart/$_appName.desktop');
    if (await desktopFile.exists()) {
      await desktopFile.delete();
    }
  }

  /// macOS: 检查 Login Item
  Future<bool> _checkMacOSLoginItem() async {
    try {
      final result = await _checkedRun(
        'osascript',
        [
          '-e',
          'tell application "System Events" to get the name of every login item'
        ],
      );
      return result.stdout.toString().contains(_appName);
    } catch (e) {
      L.e('检查 macOS Login Item 失败: $e', tag: 'AutoStart');
      return false;
    }
  }

  /// macOS: 启用 Login Item
  Future<void> _enableMacOSLoginItem() async {
    final executable = Platform.resolvedExecutable;
    final exePath = p.dirname(p.dirname(p.dirname(executable)));
    if (!exePath.endsWith('.app')) {
      throw StateError('Start the installed .app first');
    }
    await _checkedRun(
      'osascript',
      [
        '-e',
        'tell application "System Events" to make login item at end with properties {name:"$_appName", path:"$exePath", hidden:false}'
      ],
    );
  }

  /// macOS: 禁用 Login Item
  Future<void> _disableMacOSLoginItem() async {
    await _checkedRun(
      'osascript',
      [
        '-e',
        'tell application "System Events" to delete login item "$_appName"'
      ],
    );
  }

  Future<ProcessResult> _checkedRun(
      String command, List<String> arguments) async {
    final result = await Process.run(command, arguments);
    if (result.exitCode != 0) {
      throw StateError('$command failed: ${result.stderr}');
    }
    return result;
  }
}
