import 'dart:convert';
import 'dart:io';

import 'config_models.dart';
import '../utils/logger.dart';
import 'platform_paths.dart';
import 'uid.dart';

class ConfigStore {
  ConfigStore();

  Future<File> get file async => PlatformPaths.configFile();

  Future<ConfigRoot> loadOrCreate() async {
    final f = await file;
    if (!await f.exists()) {
      final created = ConfigRoot.defaults();
      final fixed = _ensureUid(created);
      await save(fixed);
      return fixed;
    }

    try {
      final raw = await f.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        final reset = _ensureUid(ConfigRoot.defaults());
        await save(reset);
        return reset;
      }
      final cfg = ConfigRoot.fromJson(decoded);
      final fixed = _ensureUid(cfg);
      // Only save if UID was actually changed
      if (fixed.network.node != cfg.network.node) {
        await save(fixed);
      }
      return fixed;
    } catch (e) {
      // Only reset on parse error, don't reset on other errors
      L.e('Failed to load config', tag: 'config', error: e);
      final reset = _ensureUid(ConfigRoot.defaults());
      await save(reset);
      return reset;
    }
  }

  Future<void> save(ConfigRoot root) async {
    final f = await file;
    final encoder = const JsonEncoder.withIndent('  ');
    var json = encoder.convert(root.toJson());
    
    // Fix token value: replace quoted string with raw number to preserve large values
    // This is needed because BigInt.toString() produces a quoted string in JSON,
    // but the core expects a numeric value
    json = json.replaceAllMapped(
      RegExp(r'"Token":\s*"(\d+)"'),
      (match) => '"Token": ${match.group(1)}',
    );
    
    await f.writeAsString(json);
  }

  ConfigRoot _ensureUid(ConfigRoot root) {
    final raw = root.network.node.trim();
    // Treat empty or all zeros as invalid
    if (raw.isEmpty || raw == '0000000000000000') {
      final uid = Uid.generate16();
      return root.copyWith(network: root.network.copyWith(node: uid));
    }
    
    // Check if it's valid 16-hex (case insensitive)
    // final isValid = RegExp(r'^[0-9a-fA-F]{16}$').hasMatch(raw);
    // if (isValid) {
      // UID is valid, return as-is without modification
      return root;
    // }
    
    // Invalid format, generate new UID
    // final uid = Uid.generate16();
    // return root.copyWith(network: root.network.copyWith(node: uid));
  }
}

