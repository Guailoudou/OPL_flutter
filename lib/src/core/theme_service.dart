import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../utils/logger.dart';
import 'platform_paths.dart';
import 'theme_models.dart';

class ThemeService extends ChangeNotifier {
  AppTheme _theme = const AppTheme();
  File? _themeFile;

  AppTheme get theme => _theme;
  AppThemeMode get mode => _theme.mode;
  Color? get customColor => _theme.customColor;

  Future<void> init() async {
    try {
      final configDir = await PlatformPaths.configDir();
      _themeFile = File(p.join(configDir.path, 'theme.json'));

      if (await _themeFile!.exists()) {
        final content = await _themeFile!.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _theme = AppTheme.fromJson(json);
        L.d('Theme loaded: ${_theme.mode}', tag: 'theme');
      } else {
        L.d('No theme file found, using defaults', tag: 'theme');
      }
    } catch (e) {
      L.e('Failed to load theme', tag: 'theme', error: e);
    }
  }

  Future<void> setMode(AppThemeMode mode) async {
    _theme = _theme.copyWith(mode: mode);
    await _save();
    notifyListeners();
  }

  Future<void> setCustomColor(Color? color) async {
    _theme = _theme.copyWith(customColor: color);
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      if (_themeFile == null) return;
      final json = _theme.toJson();
      final content = const JsonEncoder.withIndent('  ').convert(json);
      await _themeFile!.writeAsString(content);
      L.d('Theme saved: ${_theme.mode}', tag: 'theme');
    } catch (e) {
      L.e('Failed to save theme', tag: 'theme', error: e);
    }
  }
}
