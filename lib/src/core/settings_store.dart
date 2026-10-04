import 'dart:convert';
import 'dart:io';

import 'platform_paths.dart';
import 'settings_models.dart';
import 'text_document_store.dart';

class SettingsStore {
  SettingsStore({Future<File> Function()? fileProvider})
      : _document = TextDocumentStore('set.json', fileProvider: fileProvider);
  final TextDocumentStore _document;
  Future<File> get file async => PlatformPaths.settingsFile();

  Future<AppSettings> loadOrCreate() async {
    final raw = await _document.read();
    if (raw == null) {
      final def = AppSettings.defaults();
      await save(def);
      return def;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('settings root must be a JSON object');
    }
    return AppSettings.fromJson(decoded);
  }

  Future<void> save(AppSettings settings) async {
    final encoder = const JsonEncoder.withIndent('  ');
    final json = encoder.convert(settings.toJson());
    await _document.write(json);
  }
}
