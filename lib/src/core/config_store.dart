import 'dart:convert';
import 'dart:io';

import 'config_models.dart';
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
      if (fixed.network.node != cfg.network.node) {
        await save(fixed);
      }
      return fixed;
    } catch (_) {
      final reset = _ensureUid(ConfigRoot.defaults());
      await save(reset);
      return reset;
    }
  }

  Future<void> save(ConfigRoot root) async {
    final f = await file;
    final encoder = const JsonEncoder.withIndent('  ');
    final json = encoder.convert(root.toJson());
    await f.writeAsString(json);
  }

  ConfigRoot _ensureUid(ConfigRoot root) {
    final raw = root.network.node.trim().toLowerCase();
    // Treat 16-hex but all zeros as invalid so that a real random UID is generated.
    final isAllZero = raw.length == 16 && RegExp(r'^0+$').hasMatch(raw);
    if (Uid.isValid16Hex(raw) && !isAllZero) {
      if (raw == root.network.node) return root;
      return root.copyWith(network: root.network.copyWith(node: raw));
    }
    final uid = Uid.generate16();
    return root.copyWith(network: root.network.copyWith(node: uid));
  }
}

