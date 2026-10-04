import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'platform_support.dart';

class PlatformPaths {
  PlatformPaths._();

  static const MethodChannel _ohosCoreChannel =
      MethodChannel('com.example.opl_config_manager/core');

  static bool get isDesktop =>
      PlatformSupport.isWindows ||
      PlatformSupport.isLinux ||
      PlatformSupport.isMacOS;

  static bool get isOhos => PlatformSupport.isOhos;
  static Future<Directory>? _desktopDirectory;

  static Future<Directory> configDir() async {
    if (isDesktop) {
      return _desktopDirectory ??= _prepareDesktopDirectory().catchError(
        (Object error, StackTrace stack) {
          _desktopDirectory = null;
          Error.throwWithStackTrace(error, stack);
        },
      );
    }

    // OHOS uses the native UIAbilityContext.filesDir directly. This avoids
    // depending on a path_provider OHOS plugin just to obtain the sandbox path.
    if (isOhos) {
      final path = await _ohosCoreChannel.invokeMethod<String>(
        'getApplicationDocumentsDirectory',
      );
      if (path == null || path.isEmpty) {
        throw StateError('OHOS returned an empty application documents path');
      }
      return Directory(path);
    }

    // Android/iOS: app document directory (package sandbox).
    final dir = await getApplicationDocumentsDirectory();
    return dir;
  }

  static Future<Directory> _prepareDesktopDirectory() async {
    final dir =
        Directory(p.join((await getApplicationSupportDirectory()).path, 'OPL'));
    await migrateDesktopConfig(dir, [
      Directory(p.join(Directory.current.path, 'OPL')),
      Directory(p.join(p.dirname(Platform.resolvedExecutable), 'OPL')),
    ]);
    return dir;
  }

  @visibleForTesting
  static Future<void> migrateDesktopConfig(
      Directory destination, List<Directory> sources) async {
    await destination.create(recursive: true);
    for (final name in ['config.json', 'set.json']) {
      final target = File(p.join(destination.path, name));
      if (await target.exists()) continue;
      for (final root in sources) {
        final source = File(p.join(root.path, name));
        if (!await source.exists()) continue;
        final temporary = File('${target.path}.migrate');
        try {
          await source.copy(temporary.path);
          await temporary.rename(target.path);
        } finally {
          if (await temporary.exists()) await temporary.delete();
        }
        break;
      }
    }
  }

  static Future<File> configFile() async {
    final dir = await configDir();
    return File(p.join(dir.path, 'config.json'));
  }

  static Future<Directory> tempDir() async {
    if (isOhos) {
      final path =
          await _ohosCoreChannel.invokeMethod<String>('getTemporaryDirectory');
      if (path == null || path.isEmpty) {
        throw StateError('OHOS returned an empty cache path');
      }
      return Directory(path);
    }
    return Directory.systemTemp;
  }

  static Future<File> coreFile() async {
    final dir = await configDir();
    final name = _coreFileName();
    final installed = File(p.join(dir.path, name));
    if (await installed.exists() || !isDesktop) return installed;
    final bundled =
        File(p.join(p.dirname(Platform.resolvedExecutable), 'OPL', name));
    return await bundled.exists() ? bundled : installed;
  }

  static Future<File> easyTierFile() async {
    final name =
        PlatformSupport.isWindows ? 'easytier-core.exe' : 'easytier-core';
    final writable = await configDir();
    final roots = [writable];
    if (isDesktop) {
      roots.add(
          Directory(p.join(p.dirname(Platform.resolvedExecutable), 'OPL')));
    }
    for (final root in roots) {
      if (!await root.exists()) continue;
      final direct = File(p.join(root.path, name));
      if (await direct.exists()) return direct;
      await for (final entry in root.list(followLinks: false)) {
        if (entry is Directory &&
            p.basename(entry.path).startsWith('easytier-')) {
          final candidate = File(p.join(entry.path, name));
          if (await candidate.exists()) return candidate;
        }
      }
    }
    return File(p.join(writable.path, name));
  }

  static Future<File> settingsFile() async {
    final dir = await configDir();
    return File(p.join(dir.path, 'set.json'));
  }

  static String _coreFileName() {
    if (PlatformSupport.isWindows) return 'openp2p-opl.exe';
    if (PlatformSupport.isLinux) return 'openp2p-opl';
    if (PlatformSupport.isMacOS) return 'openp2p-opl';
    // Mobile reserved interface:
    return 'opl-core';
  }
}
