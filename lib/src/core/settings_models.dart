enum AppThemeMode { system, light, dark }

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.coreVersion,
    required this.lastNoticeTime,
  });

  final AppThemeMode themeMode;
  final String? coreVersion;
  final String? lastNoticeTime;

  factory AppSettings.defaults() {
    return const AppSettings(
      themeMode: AppThemeMode.system,
      coreVersion: null,
      lastNoticeTime: null,
    );
  }

  AppSettings copyWith({
    AppThemeMode? themeMode,
    String? coreVersion,
    String? lastNoticeTime,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      coreVersion: coreVersion ?? this.coreVersion,
      lastNoticeTime: lastNoticeTime ?? this.lastNoticeTime,
    );
  }

  static AppThemeMode _themeFromString(String? v) {
    switch (v) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      case 'system':
      default:
        return AppThemeMode.system;
    }
  }

  static String _themeToString(AppThemeMode m) {
    switch (m) {
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
      case AppThemeMode.system:
        return 'system';
    }
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: _themeFromString(json['themeMode'] as String?),
      coreVersion: json['coreVersion'] as String?,
      lastNoticeTime: json['lastNoticeTime'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': _themeToString(themeMode),
        'coreVersion': coreVersion,
        'lastNoticeTime': lastNoticeTime,
      };
}

