enum AppThemeMode { system, light, dark }

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.coreVersion,
    required this.easytierVersion,
    required this.lastNoticeTime,
    required this.runInBackground,
    required this.askBeforeMinimize,
    required this.useGiteeMirror,
    required this.apiBase,
    required this.autoStart,
    required this.autoStartCore,
    required this.ispWarning,
  });

  final AppThemeMode themeMode;
  final String? coreVersion;
  final String? easytierVersion;
  final String? lastNoticeTime;
  final bool runInBackground;
  final bool askBeforeMinimize;
  final bool useGiteeMirror;
  final String apiBase;
  final bool autoStart;
  final bool autoStartCore;
  final bool ispWarning;

  factory AppSettings.defaults() {
    return const AppSettings(
      themeMode: AppThemeMode.system,
      coreVersion: null,
      easytierVersion: null,
      lastNoticeTime: null,
      runInBackground: false,
      askBeforeMinimize: true,
      useGiteeMirror: false,
      apiBase: 'http://localhost:3000',
      autoStart: false,
      autoStartCore: false,
      ispWarning: true,
    );
  }

  AppSettings copyWith({
    AppThemeMode? themeMode,
    String? coreVersion,
    String? easytierVersion,
    String? lastNoticeTime,
    bool? runInBackground,
    bool? askBeforeMinimize,
    bool? useGiteeMirror,
    String? apiBase,
    bool? autoStart,
    bool? autoStartCore,
    bool? ispWarning,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      coreVersion: coreVersion ?? this.coreVersion,
      easytierVersion: easytierVersion ?? this.easytierVersion,
      lastNoticeTime: lastNoticeTime ?? this.lastNoticeTime,
      runInBackground: runInBackground ?? this.runInBackground,
      askBeforeMinimize: askBeforeMinimize ?? this.askBeforeMinimize,
      useGiteeMirror: useGiteeMirror ?? this.useGiteeMirror,
      apiBase: apiBase ?? this.apiBase,
      autoStart: autoStart ?? this.autoStart,
      autoStartCore: autoStartCore ?? this.autoStartCore,
      ispWarning: ispWarning ?? this.ispWarning,
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
      easytierVersion: json['easytierVersion'] as String?,
      lastNoticeTime: json['lastNoticeTime'] as String?,
      runInBackground: json['runInBackground'] as bool? ?? false,
      askBeforeMinimize: json['askBeforeMinimize'] as bool? ?? true,
      useGiteeMirror: json['useGiteeMirror'] as bool? ?? false,
      apiBase: json['apiBase'] as String? ?? 'http://localhost:3000',
      autoStart: json['autoStart'] as bool? ?? false,
      autoStartCore: json['autoStartCore'] as bool? ?? false,
      ispWarning: json['ispWarning'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': _themeToString(themeMode),
        'coreVersion': coreVersion,
        'easytierVersion': easytierVersion,
        'lastNoticeTime': lastNoticeTime,
        'runInBackground': runInBackground,
        'askBeforeMinimize': askBeforeMinimize,
        'useGiteeMirror': useGiteeMirror,
        'apiBase': apiBase,
        'autoStart': autoStart,
        'autoStartCore': autoStartCore,
        'ispWarning': ispWarning,
      };
}

