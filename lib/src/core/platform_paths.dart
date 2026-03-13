import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PlatformPaths {
  PlatformPaths._();

  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static Future<Directory> configDir() async {
    if (isDesktop) {
      // Desktop requirement: "OPL" folder next to executable.
      // We use Directory.current as a pragmatic default; when packaged, it is
      // typically the executable directory.
      final dir = Directory(p.join(Directory.current.path, 'OPL'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    // Mobile requirement: app document directory (package sandbox).
    final dir = await getApplicationDocumentsDirectory();
    return dir;
  }

  static Future<File> configFile() async {
    final dir = await configDir();
    return File(p.join(dir.path, 'config.json'));
  }

  static Future<File> coreFile() async {
    final dir = await configDir();
    final name = _coreFileName();
    return File(p.join(dir.path, name));
  }

  static Future<File> settingsFile() async {
    final dir = await configDir();
    return File(p.join(dir.path, 'set.json'));
  }

  static String _coreFileName() {
    if (Platform.isWindows) return 'openp2p-opl.exe';
    if (Platform.isLinux) return 'openp2p-opl';
    if (Platform.isMacOS) return 'openp2p-opl';
    // Mobile reserved interface:
    return 'opl-core';
  }
}

