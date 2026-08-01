import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../core/platform_paths.dart';
import '../core/url_config.dart';
import '../models/release_info.dart';
import '../models/semver.dart';
import '../utils/logger.dart';

enum UpdateComponent { app, core, easytier }

enum UpdateState {
  idle,
  checking,
  updateAvailable,
  downloading,
  extracting,
  upToDate,
  error,
}

class UpdateService extends ChangeNotifier {
  final Map<UpdateComponent, UpdateState> _states = {
    for (final c in UpdateComponent.values) c: UpdateState.idle,
  };
  final Map<UpdateComponent, double> _progress = {
    for (final c in UpdateComponent.values) c: 0.0,
  };
  final Map<UpdateComponent, String?> _installedVersions = {
    for (final c in UpdateComponent.values) c: null,
  };

  ReleaseInfo? _cachedRelease;
  void Function(String version)? onCoreVersionChanged;
  void Function(String version)? onEasytierVersionChanged;

  UpdateService({
    this.onCoreVersionChanged,
    this.onEasytierVersionChanged,
  });

  // === Public API ===

  UpdateState getState(UpdateComponent component) => _states[component] ?? UpdateState.idle;
  double getProgress(UpdateComponent component) => _progress[component] ?? 0.0;
  String? getInstalledVersion(UpdateComponent component) => _installedVersions[component];
  String? getLatestVersion(UpdateComponent component) {
    final release = _cachedRelease;
    if (release == null) return null;
    switch (component) {
      case UpdateComponent.app:
        return release.app?.version;
      case UpdateComponent.core:
        return release.getCoreForCurrentPlatform()?.version;
      case UpdateComponent.easytier:
        return release.getEasytierForCurrentPlatform()?.version;
    }
  }

  Future<void> detectInstalledVersions() async {
    // App version
    try {
      final info = await PackageInfo.fromPlatform();
      _installedVersions[UpdateComponent.app] = info.version;
    } catch (e) {
      L.w('Failed to get app version: $e', tag: 'update');
    }

    // Core version
    final coreFile = await PlatformPaths.coreFile();
    if (await coreFile.exists()) {
      try {
        final result = await Process.run(coreFile.path, ['--version']);
        if (result.exitCode == 0) {
          final match = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(result.stdout.toString());
          if (match != null) {
            _installedVersions[UpdateComponent.core] = match.group(1);
          }
        }
      } catch (_) {
        // ignore
      }
    }

    // EasyTier version
    final easyTierExe = await _getEasyTierExePath();
    if (await File(easyTierExe).exists()) {
      try {
        final result = await Process.run(easyTierExe, ['--version']);
        if (result.exitCode == 0) {
          final match = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(result.stdout.toString());
          if (match != null) {
            _installedVersions[UpdateComponent.easytier] = match.group(1);
          }
        }
        if (_installedVersions[UpdateComponent.easytier] == null) {
          final helpResult = await Process.run(easyTierExe, ['--help']);
          if (helpResult.exitCode == 0) {
            final match = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(helpResult.stdout.toString());
            if (match != null) {
              _installedVersions[UpdateComponent.easytier] = match.group(1);
            }
          }
        }
      } catch (_) {
        // ignore
      }
    }

    notifyListeners();
  }

  Future<void> checkAllUpdates() async {
    try {
      _setAllStates(UpdateState.checking);
      notifyListeners();

      _cachedRelease = await _fetchReleaseInfo();

      for (final component in UpdateComponent.values) {
        final installed = _installedVersions[component];
        final latest = getLatestVersion(component);

        if (latest == null) {
          _states[component] = UpdateState.idle;
          continue;
        }

        if (installed == null || installed.isEmpty) {
          _states[component] = UpdateState.updateAvailable;
          continue;
        }

        try {
          final installedSem = SemVer.parse(installed);
          final latestSem = SemVer.parse(latest);
          if (latestSem > installedSem) {
            _states[component] = UpdateState.updateAvailable;
          } else {
            _states[component] = UpdateState.upToDate;
          }
        } catch (_) {
          // Fallback to string comparison
          if (latest != installed) {
            _states[component] = UpdateState.updateAvailable;
          } else {
            _states[component] = UpdateState.upToDate;
          }
        }
      }
    } catch (e) {
      L.w('Failed to check updates: $e', tag: 'update');
      _setAllStates(UpdateState.idle);
    }
    notifyListeners();
  }

  Future<void> downloadAndInstall(
    UpdateComponent component, {
    void Function(double progress)? onProgress,
  }) async {
    final release = _cachedRelease ?? await _fetchReleaseInfo();
    _cachedRelease = release;

    _states[component] = UpdateState.downloading;
    _progress[component] = 0.0;
    notifyListeners();

    try {
      final url = _getDownloadUrl(release, component);
      if (url == null || url.isEmpty) {
        throw StateError('No download URL for $component on this platform');
      }

      final expectedHash = _getExpectedHash(release, component);
      final version = getLatestVersion(component) ?? '';

      final bytes = await _downloadWithProgress(url, (progress) {
        _progress[component] = progress;
        onProgress?.call(progress);
        notifyListeners();
      });

      // Verify hash
      if (expectedHash.isNotEmpty && expectedHash != 'placeholder_hash') {
        final digest = sha256.convert(bytes).toString();
        if (digest.toLowerCase() != expectedHash.toLowerCase()) {
          throw StateError('File hash mismatch (sha256)');
        }
      }

      _states[component] = UpdateState.extracting;
      notifyListeners();

      switch (component) {
        case UpdateComponent.core:
          await _extractCore(bytes, version);
          _installedVersions[UpdateComponent.core] = version;
          onCoreVersionChanged?.call(version);
          break;
        case UpdateComponent.easytier:
          await _extractEasyTier(bytes, version);
          // Detect actual version
          final actualVersion = await _getEasyTierVersion() ?? version;
          _installedVersions[UpdateComponent.easytier] = actualVersion;
          onEasytierVersionChanged?.call(actualVersion);
          break;
        case UpdateComponent.app:
          await _installApp(bytes, version);
          _installedVersions[UpdateComponent.app] = version;
          break;
      }

      _states[component] = UpdateState.upToDate;
      _progress[component] = 1.0;
    } catch (e) {
      L.e('Failed to download/install $component', tag: 'update', error: e);
      _states[component] = UpdateState.error;
    }
    notifyListeners();
  }

  // === Internal ===

  Future<ReleaseInfo> _fetchReleaseInfo() async {
    final resp = await http.get(Uri.parse(UrlConfig.releasesApiUrl));
    if (resp.statusCode != 200) {
      throw StateError('Failed to fetch releases: HTTP ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Invalid releases response');
    }
    return ReleaseInfo.fromJson(decoded);
  }

  String? _getDownloadUrl(ReleaseInfo release, UpdateComponent component) {
    final platform = _platformKey();
    if (platform == null) return null;
    switch (component) {
      case UpdateComponent.app:
        return release.app?.urlForPlatform(platform);
      case UpdateComponent.core:
        return release.getCoreForCurrentPlatform()?.url;
      case UpdateComponent.easytier:
        return release.getEasytierForCurrentPlatform()?.url;
    }
  }

  String _getExpectedHash(ReleaseInfo release, UpdateComponent component) {
    final platform = _platformKey();
    if (platform == null) return '';
    switch (component) {
      case UpdateComponent.app:
        return release.app?.hashForPlatform(platform) ?? '';
      case UpdateComponent.core:
        return release.getCoreForCurrentPlatform()?.hash ?? '';
      case UpdateComponent.easytier:
        return release.getEasytierForCurrentPlatform()?.hash ?? '';
    }
  }

  String? _platformKey() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    return null;
  }

  Future<List<int>> _downloadWithProgress(
    String url,
    void Function(double progress) onProgress,
  ) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final streamed = await client.send(request);

      if (streamed.statusCode != 200) {
        throw StateError('Download failed: HTTP ${streamed.statusCode}');
      }

      final total = streamed.contentLength ?? 0;
      final bytes = <int>[];
      int received = 0;

      await for (final chunk in streamed.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress(received / total);
        }
      }

      // If total unknown, report 99% during download, 100% at end
      if (total <= 0) {
        onProgress(0.99);
      }
      onProgress(1.0);

      return bytes;
    } finally {
      client.close();
    }
  }

  Future<void> _extractCore(List<int> bytes, String version) async {
    final dir = await PlatformPaths.configDir();
    final core = await PlatformPaths.coreFile();

    final decoded = GZipDecoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(decoded);

    File? extractedExe;
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = p.basename(file.name);
      final outPath = p.join(dir.path, name);
      final outFile = File(outPath);
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(file.content as List<int>, flush: true);

      final lower = name.toLowerCase();
      if (Platform.isWindows) {
        if (lower.endsWith('.exe')) {
          extractedExe ??= outFile;
        }
      } else {
        if (!lower.endsWith('.md')) {
          extractedExe ??= outFile;
        }
      }
    }

    if (extractedExe == null) {
      throw StateError('Extraction failed: no executable found');
    }

    if (extractedExe.path != core.path) {
      await extractedExe.rename(core.path);
    }

    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['+x', core.path]);
      } catch (_) {
        // ignore
      }
    }

    L.i('Core installed: ${core.path}', tag: 'update');
  }

  Future<void> _extractEasyTier(List<int> bytes, String version) async {
    final configDir = await PlatformPaths.configDir();
    final zipPath = p.join(configDir.path, 'easytier.zip');

    final zipFile = File(zipPath);
    await zipFile.writeAsBytes(bytes);

    final archiveBytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(archiveBytes);

    for (final file in archive) {
      final filename = p.join(configDir.path, file.name);
      if (file.isFile) {
        final outFile = File(filename);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(filename).create(recursive: true);
      }
    }

    await zipFile.delete();

    if (!Platform.isWindows) {
      final exePath = await _getEasyTierExePath();
      if (await File(exePath).exists()) {
        await Process.run('chmod', ['+x', exePath]);
      }
    }

    L.i('EasyTier installed', tag: 'update');
  }

  Future<void> _installApp(List<int> bytes, String version) async {
    final configDir = await PlatformPaths.configDir();
    final platform = _platformKey();

    if (Platform.isWindows) {
      final installerPath = p.join(configDir.path, 'opl_installer.exe');
      final installer = File(installerPath);
      await installer.writeAsBytes(bytes);
      // Launch installer
      await Process.run(installerPath, []);
      L.i('App installer launched', tag: 'update');
    } else if (Platform.isMacOS) {
      final dmgPath = p.join(configDir.path, 'opl_installer.dmg');
      final dmg = File(dmgPath);
      await dmg.writeAsBytes(bytes);
      await Process.run('open', [dmgPath]);
      L.i('App DMG opened', tag: 'update');
    } else if (Platform.isLinux) {
      final tarPath = p.join(configDir.path, 'opl_installer.tar.gz');
      final tarFile = File(tarPath);
      await tarFile.writeAsBytes(bytes);
      // Extract and replace
      final decoded = GZipDecoder().decodeBytes(bytes);
      final archive = TarDecoder().decodeBytes(decoded);
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final name = p.basename(file.name);
        final outPath = p.join(configDir.path, name);
        final outFile = File(outPath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>, flush: true);
        if (name.endsWith('.AppImage') || !name.contains('.')) {
          await Process.run('chmod', ['+x', outPath]);
        }
      }
      await tarFile.delete();
      L.i('App updated on Linux', tag: 'update');
    }
  }

  Future<String?> _getEasyTierVersion() async {
    final exePath = await _getEasyTierExePath();
    if (!await File(exePath).exists()) return null;

    try {
      final result = await Process.run(exePath, ['--version']);
      if (result.exitCode == 0) {
        final match = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(result.stdout.toString());
        if (match != null) return match.group(1);
      }
      final helpResult = await Process.run(exePath, ['--help']);
      if (helpResult.exitCode == 0) {
        final match = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(helpResult.stdout.toString());
        if (match != null) return match.group(1);
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  Future<String> _getEasyTierExePath() async {
    final configDir = await PlatformPaths.configDir();
    final exeName = Platform.isWindows ? 'easytier-core.exe' : 'easytier-core';
    final subfolder = _getEasyTierSubfolder();
    return p.join(configDir.path, subfolder, exeName);
  }

  String _getEasyTierSubfolder() {
    if (Platform.isWindows) return 'easytier-windows-x86_64';
    if (Platform.isLinux) return 'easytier-linux-x86_64';
    if (Platform.isMacOS) return 'easytier-macos';
    return 'easytier-unknown';
  }

  void _setAllStates(UpdateState state) {
    for (final c in UpdateComponent.values) {
      _states[c] = state;
    }
  }
}
