import 'dart:convert';
import 'dart:io';

import 'config_models.dart';
import 'platform_paths.dart';
import 'text_document_store.dart';
import 'uid.dart';

class ConfigStore {
  ConfigStore({Future<File> Function()? fileProvider})
      : _document =
            TextDocumentStore('config.json', fileProvider: fileProvider);

  final TextDocumentStore _document;

  Future<File> get file async => PlatformPaths.configFile();

  Future<ConfigRoot> loadOrCreate() async {
    final raw = await _document.read();
    if (raw == null) {
      final created = ConfigRoot.defaults();
      final fixed = _ensureUid(created);
      await save(fixed);
      return fixed;
    }

    // Surface read/parse failures; never overwrite the user's configuration.
    final cfg = decode(raw);
    final fixed = _ensureUid(cfg);
    if (fixed.network.node != cfg.network.node) {
      await save(fixed);
    }
    return fixed;
  }

  /// Decodes config JSON without routing an unsigned 64-bit token through a
  /// Dart [num]. Dart/ArkTS cannot represent every uint64 value exactly, while
  /// OpenP2P intentionally stores Token as a raw JSON integer. Quote only that
  /// field in the in-memory JSON copy so [NetworkConfig] can use BigInt.parse.
  static ConfigRoot decode(String raw) {
    final precisionSafeJson = raw.replaceAllMapped(
      RegExp(r'("(?:Token|token)"\s*:\s*)(\d+)(\s*[,}])'),
      (match) => '${match.group(1)}"${match.group(2)}"${match.group(3)}',
    );
    final decoded = jsonDecode(precisionSafeJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('config root must be a JSON object');
    }
    return ConfigRoot.fromJson(decoded);
  }

  Future<void> save(ConfigRoot root) async {
    if (root.network.token < BigInt.zero ||
        root.network.token >= (BigInt.one << 64)) {
      throw const FormatException('Token is outside the unsigned 64-bit range');
    }
    final encoder = const JsonEncoder.withIndent('  ');
    var json = encoder.convert(root.toJson());

    // Keep the on-disk value as an exact raw uint64 for the Go core. load() uses
    // a precision-safe in-memory representation before Dart parses the JSON.
    json = json.replaceAllMapped(
      RegExp(r'"Token":\s*"(\d+)"'),
      (match) => '"Token": ${match.group(1)}',
    );

    await _document.write(json);
  }

  ConfigRoot _ensureUid(ConfigRoot root) {
    final raw = root.network.node.trim();
    if (!RegExp(r'^[0-9a-fA-F]{16}$').hasMatch(raw) ||
        raw == '0000000000000000') {
      final uid = Uid.generate16();
      return root.copyWith(network: root.network.copyWith(node: uid));
    }

    return root;
  }
}
