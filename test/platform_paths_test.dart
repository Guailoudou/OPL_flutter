import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opl_config_manager/src/core/platform_paths.dart';

void main() {
  test(
      'migrates legacy working-directory data into an existing support directory',
      () async {
    final root = await Directory.systemTemp.createTemp('opl_migration_');
    try {
      final destination = await Directory('${root.path}/support').create();
      final working =
          await Directory('${root.path}/working/OPL').create(recursive: true);
      final bundled =
          await Directory('${root.path}/bundle/OPL').create(recursive: true);
      await File('${working.path}/config.json').writeAsString('{broken');
      await File('${working.path}/set.json').writeAsString('old settings');
      await File('${bundled.path}/config.json').writeAsString('other config');
      await File('${working.path}/openp2p-opl').writeAsString('binary');
      await File('${destination.path}/set.json')
          .writeAsString('current settings');

      await PlatformPaths.migrateDesktopConfig(destination, [working, bundled]);
      expect(await File('${destination.path}/config.json').readAsString(),
          '{broken');
      expect(await File('${destination.path}/set.json').readAsString(),
          'current settings');
      expect(await File('${destination.path}/openp2p-opl').exists(), isFalse);
      expect(await File('${destination.path}/config.json.migrate').exists(),
          isFalse);

      await File('${working.path}/config.json').writeAsString('changed legacy');
      await PlatformPaths.migrateDesktopConfig(destination, [working, bundled]);
      expect(await File('${destination.path}/config.json').readAsString(),
          '{broken');
    } finally {
      await root.delete(recursive: true);
    }
  });
}
