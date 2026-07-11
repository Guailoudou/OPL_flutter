import 'dart:io';

class ReleaseInfo {
  final AppReleaseInfo? app;
  final Map<String, PlatformRelease> core;
  final Map<String, PlatformRelease> easytier;

  const ReleaseInfo({this.app, required this.core, required this.easytier});

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final appData = json['app'];
    final coreData = json['core'] as Map<String, dynamic>? ?? {};
    final easytierData = json['easytier'] as Map<String, dynamic>? ?? {};

    return ReleaseInfo(
      app: appData is Map<String, dynamic>
          ? AppReleaseInfo.fromJson(appData)
          : null,
      core: coreData.map(
        (k, v) => MapEntry(k, PlatformRelease.fromJson(v as Map<String, dynamic>)),
      ),
      easytier: easytierData.map(
        (k, v) => MapEntry(k, PlatformRelease.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }

  PlatformRelease? getCoreForCurrentPlatform() {
    return _platformRelease(core);
  }

  PlatformRelease? getEasytierForCurrentPlatform() {
    return _platformRelease(easytier);
  }

  PlatformRelease? _platformRelease(Map<String, PlatformRelease> map) {
    final platform = _currentPlatformKey();
    return platform != null ? map[platform] : null;
  }

  static String? _currentPlatformKey() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    return null;
  }
}

class AppReleaseInfo {
  final String version;
  final int buildNumber;
  final String changelog;
  final Map<String, String> urls;
  final Map<String, String> hashes;

  const AppReleaseInfo({
    required this.version,
    required this.buildNumber,
    required this.changelog,
    required this.urls,
    required this.hashes,
  });

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final urlData = json['url'] as Map<String, dynamic>? ?? {};
    final hashData = json['hash'] as Map<String, dynamic>? ?? {};

    return AppReleaseInfo(
      version: json['version'] as String? ?? '',
      buildNumber: json['buildNumber'] as int? ?? 0,
      changelog: json['changelog'] as String? ?? '',
      urls: urlData.map((k, v) => MapEntry(k, v.toString())),
      hashes: hashData.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  String? urlForPlatform(String platform) => urls[platform];
  String? hashForPlatform(String platform) => hashes[platform];
}

class PlatformRelease {
  final String version;
  final String url;
  final String hash;
  final String? filename;

  const PlatformRelease({
    required this.version,
    required this.url,
    required this.hash,
    this.filename,
  });

  factory PlatformRelease.fromJson(Map<String, dynamic> json) {
    return PlatformRelease(
      version: json['version'] as String? ?? '',
      url: json['url'] as String? ?? '',
      hash: json['hash'] as String? ?? '',
      filename: json['filename'] as String?,
    );
  }
}
