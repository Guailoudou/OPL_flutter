import 'package:flutter/material.dart';

enum AppThemeMode {
  light,
  dark,
  system,
}

class AppTheme {
  final AppThemeMode mode;
  final Color? customColor;

  const AppTheme({
    this.mode = AppThemeMode.system,
    this.customColor,
  });

  AppTheme copyWith({
    AppThemeMode? mode,
    Color? customColor,
  }) {
    return AppTheme(
      mode: mode ?? this.mode,
      customColor: customColor ?? this.customColor,
    );
  }

  ThemeMode get flutterThemeMode {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.index,
      // Retain compatibility with the OHOS Flutter SDK.
      // ignore: deprecated_member_use
      'customColor': customColor?.value,
    };
  }

  factory AppTheme.fromJson(Map<String, dynamic> json) {
    return AppTheme(
      mode: AppThemeMode.values[json['mode'] as int? ?? 2],
      customColor: json['customColor'] != null
          ? Color(json['customColor'] as int)
          : null,
    );
  }
}
