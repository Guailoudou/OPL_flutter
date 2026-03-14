enum AppThemeMode { system, light, dark }

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.coreVersion,
    required this.lastNoticeTime,
    required this.runInBackground,
    required this.askBeforeMinimize,
  });

  final AppThemeMode themeMode;
  final String? coreVersion;
  final String? lastNoticeTime;
  final bool runInBackground;
  final bool askBeforeMinimize;

  factory AppSettings.defaults() {
    return const AppSettings(
      themeMode: AppThemeMode.system,
      coreVersion: null,
      lastNoticeTime: null,
      runInBackground: false,
      askBeforeMinimize: true,
    );
  }

  AppSettings copyWith({
    AppThemeMode? themeMode,
    String? coreVersion,
    String? lastNoticeTime,
    bool? runInBackground,
    bool? askBeforeMinimize,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      coreVersion: coreVersion ?? this.coreVersion,
      lastNoticeTime: lastNoticeTime ?? this.lastNoticeTime,
      runInBackground: runInBackground ?? this.runInBackground,
      askBeforeMinimize: askBeforeMinimize ?? this.askBeforeMinimize,
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
      runInBackground: json['runInBackground'] as bool? ?? false,
      askBeforeMinimize: json['askBeforeMinimize'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': _themeToString(themeMode),
        'coreVersion': coreVersion,
        'lastNoticeTime': lastNoticeTime,
        'runInBackground': runInBackground,
        'askBeforeMinimize': askBeforeMinimize,
      };
}

