import 'dart:convert';
import 'dart:io';

import 'platform_paths.dart';
import 'settings_models.dart';

class SettingsStore {
  Future<File> get file async => PlatformPaths.settingsFile();

  Future<AppSettings> loadOrCreate() async {
    final f = await file;
    if (!await f.exists()) {
      final def = AppSettings.defaults();
      await save(def);
      return def;
    }
    try {
      final raw = await f.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        final def = AppSettings.defaults();
        await save(def);
        return def;
      }
      return AppSettings.fromJson(decoded);
    } catch (_) {
      final def = AppSettings.defaults();
      await save(def);
      return def;
    }
  }

  Future<void> save(AppSettings settings) async {
    final f = await file;
    final encoder = const JsonEncoder.withIndent('  ');
    final json = encoder.convert(settings.toJson());
    await f.writeAsString(json);
  }
}

