import 'dart:async';
import 'dart:io';

import 'safe_archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../core/platform_paths.dart';
import '../core/platform_support.dart';
import '../core/remote_json.dart';
import '../core/url_config.dart';
import '../core/android_core_service.dart';
import '../core/ohos_core_service.dart';
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
  installReady,
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
  Future<void> Function(UpdateComponent)? beforeInstall;
  bool _disposed = false;
  bool _installing = false;
  String? appInstallPath;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool supports(UpdateComponent component) => component == UpdateComponent.app
      ? PlatformSupport.isDesktop || PlatformSupport.isAndroid
      : PlatformSupport.isDesktop;

  void Function(String version)? onCoreVersionChanged;
  void Function(String version)? onEasytierVersionChanged;

  UpdateService({
    this.onCoreVersionChanged,
    this.onEasytierVersionChanged,
  });

  // === Public API ===

  UpdateState getState(UpdateComponent component) =>
      _states[component] ?? UpdateState.idle;
  double getProgress(UpdateComponent component) => _progress[component] ?? 0.0;
  String? getInstalledVersion(UpdateComponent component) =>
      _installedVersions[component];
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
    if (PlatformSupport.isOhos) {
      // package_info_plus currently has no OHOS implementation. Keep the
      // version check functional without invoking an unregistered channel.
      _installedVersions[UpdateComponent.app] =
          await OhosCoreService.getAppVersion();
    } else {
      try {
        final info = await PackageInfo.fromPlatform();
        _installedVersions[UpdateComponent.app] = info.version;
      } catch (e) {
        L.w('Failed to get app version: $e', tag: 'update');
      }
    }

    if (!PlatformSupport.isDesktop) {
      notifyListeners();
      return;
    }

    // Core version
    final coreFile = await PlatformPaths.coreFile();
    if (await coreFile.exists()) {
      try {
        final result = await _runVersion(coreFile.path, ['--version']);
        if (result.exitCode == 0) {
          final match =
              RegExp(r'(\d+\.\d+\.\d+)').firstMatch(result.stdout.toString());
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
        final result = await _runVersion(easyTierExe, ['--version']);
        if (result.exitCode == 0) {
          final match =
              RegExp(r'(\d+\.\d+\.\d+)').firstMatch(result.stdout.toString());
          if (match != null) {
            _installedVersions[UpdateComponent.easytier] = match.group(1);
          }
        }
        if (_installedVersions[UpdateComponent.easytier] == null) {
          final helpResult = await _runVersion(easyTierExe, ['--help']);
          if (helpResult.exitCode == 0) {
            final match = RegExp(r'(\d+\.\d+\.\d+)')
                .firstMatch(helpResult.stdout.toString());
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
        if (!supports(component)) {
          _states[component] = UpdateState.idle;
          continue;
        }
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
    if (!supports(component)) {
      throw UnsupportedError('Updates are unavailable on this platform');
    }
    if (_installing) throw StateError('Another update is already in progress');
    _installing = true;
    Directory? temporary;
    _states[component] = UpdateState.downloading;
    _progress[component] = 0.0;
    notifyListeners();

    try {
      final release = _cachedRelease ?? await _fetchReleaseInfo();
      _cachedRelease = release;
      final url = _getDownloadUrl(release, component);
      if (url == null || url.isEmpty) {
        throw StateError('No download URL for $component on this platform');
      }

      final expectedHash = _getExpectedHash(release, component);
      final version = getLatestVersion(component) ?? '';
      if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(expectedHash)) {
        throw const FormatException(
            'A valid SHA256 is required for every update');
      }
      if (!RegExp(r'^[0-9A-Za-z.+-]+$').hasMatch(version)) {
        throw const FormatException('Invalid version');
      }
      temporary = await Directory.systemTemp.createTemp('opl_update_');

      final package = await _downloadWithProgress(url, temporary, (progress) {
        _progress[component] = progress;
        onProgress?.call(progress);
        notifyListeners();
      });

      final digest = (await sha256.bind(package.openRead()).first).toString();
      if (digest.toLowerCase() != expectedHash.toLowerCase()) {
        throw StateError('File hash mismatch (sha256)');
      }
      await beforeInstall?.call(component);

      _states[component] = UpdateState.extracting;
      notifyListeners();

      switch (component) {
        case UpdateComponent.core:
          await _extractCore(package, temporary);
          _installedVersions[UpdateComponent.core] = version;
          onCoreVersionChanged?.call(version);
          break;
        case UpdateComponent.easytier:
          await _extractEasyTier(package, temporary);
          // Detect actual version
          final actualVersion = await _getEasyTierVersion() ?? version;
          _installedVersions[UpdateComponent.easytier] = actualVersion;
          onEasytierVersionChanged?.call(actualVersion);
          break;
        case UpdateComponent.app:
          await _installApp(package, version, url, temporary);
          break;
      }

      _states[component] = component == UpdateComponent.app
          ? UpdateState.installReady
          : UpdateState.upToDate;
      _progress[component] = 1.0;
    } catch (e) {
      L.e('Failed to download/install $component', tag: 'update', error: e);
      _states[component] = UpdateState.error;
      notifyListeners();
      rethrow;
    } finally {
      _installing = false;
      if (temporary != null && await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    }
    notifyListeners();
  }

  // === Internal ===

  Future<ReleaseInfo> _fetchReleaseInfo() async {
    final decoded = await fetchJsonDocument(UrlConfig.releasesJsonUrl);
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
    if (PlatformSupport.isWindows) return 'windows';
    if (PlatformSupport.isLinux) return 'linux';
    if (PlatformSupport.isMacOS) return 'macos';
    if (PlatformSupport.isAndroid) return 'android';
    if (PlatformSupport.isOhos) return 'ohos';
    return null;
  }

  Future<File> _downloadWithProgress(
    String url,
    Directory temporary,
    void Function(double progress) onProgress,
  ) async {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Downloads require HTTPS');
    }
    final client = http.Client();
    final file = File(p.join(temporary.path, 'download'));
    final sink = file.openWrite();
    const limit = 512 * 1024 * 1024;
    try {
      final response = await client
          .send(http.Request('GET', uri))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw StateError('Download failed: HTTP ${response.statusCode}');
      }
      final total = response.contentLength ?? 0;
      if (total > limit) throw StateError('Download is too large');
      var received = 0;
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 30))) {
        received += chunk.length;
        if (received > limit) throw StateError('Download is too large');
        sink.add(chunk);
        if (total > 0) onProgress(received / total);
      }
      if (total > 0 && total != received) {
        throw StateError('Incomplete download');
      }
      await sink.flush();
      onProgress(1);
      return file;
    } finally {
      await sink.close();
      client.close();
    }
  }

  Future<void> _replaceBinary(File source, File destination) async {
    await destination.parent.create(recursive: true);
    final staged = await source.copy('${destination.path}.new');
    try {
      if (!PlatformSupport.isWindows) {
        final result = await Process.run('chmod', ['+x', staged.path]);
        if (result.exitCode != 0) throw StateError('Unable to make executable');
      }
      await staged.rename(destination.path);
    } finally {
      if (await staged.exists()) await staged.delete();
    }
  }

  Future<File> _findBinary(Directory dir, Set<String> names) async {
    final files = await dir
        .list(recursive: true, followLinks: false)
        .where(
            (entry) => entry is File && names.contains(p.basename(entry.path)))
        .cast<File>()
        .toList();
    if (files.length != 1) {
      throw const FormatException(
          'Archive must contain exactly one expected executable');
    }
    return files.single;
  }

  Future<void> _extractCore(File package, Directory temporary) async {
    final staging = Directory(p.join(temporary.path, 'core'));
    await extractArchiveSafely(package, staging);
    final name = PlatformSupport.isWindows ? 'openp2p-opl.exe' : 'openp2p-opl';
    final binary = await _findBinary(
        staging, {name, PlatformSupport.isWindows ? 'openp2p.exe' : 'openp2p'});
    final destination =
        File(p.join((await PlatformPaths.configDir()).path, name));
    await _replaceBinary(binary, destination);
    if (PlatformSupport.isWindows) {
      final driver = File(
          p.join(p.dirname(Platform.resolvedExecutable), 'OPL', 'wintun.dll'));
      final installedDriver =
          File(p.join(destination.parent.path, 'wintun.dll'));
      if (await driver.exists() && !await installedDriver.exists()) {
        await driver.copy(installedDriver.path);
      }
    }
  }

  Future<void> _extractEasyTier(File package, Directory temporary) async {
    final staging = Directory(p.join(temporary.path, 'easytier'));
    await extractArchiveSafely(package, staging);
    final name =
        PlatformSupport.isWindows ? 'easytier-core.exe' : 'easytier-core';
    final binary = await _findBinary(staging, {name});
    final dir = await PlatformPaths.configDir();
    // Preserve the companion CLI and DLLs shipped alongside the core.
    await for (final entry in binary.parent.list(followLinks: false)) {
      if (entry is File) {
        await _replaceBinary(
            entry, File(p.join(dir.path, p.basename(entry.path))));
      }
    }
  }

  Future<void> _installApp(
      File package, String version, String url, Directory temporary) async {
    final dir = await PlatformPaths.configDir();
    final extension = p.extension(Uri.parse(url).path).toLowerCase();
    if (PlatformSupport.isAndroid) {
      final apk = await package.copy(p.join(dir.path, 'opl-$version.apk'));
      if (!await AndroidCoreService.installApk(apk.path)) {
        throw StateError('Unable to open APK installer');
      }
      return;
    }
    if (PlatformSupport.isWindows && extension == '.exe') {
      final installer =
          await package.copy(p.join(dir.path, 'opl-installer-$version.exe'));
      await Process.start(installer.path, [], mode: ProcessStartMode.detached);
      return;
    }
    if (PlatformSupport.isMacOS && extension == '.dmg') {
      final dmg = await package.copy(p.join(dir.path, 'opl-$version.dmg'));
      final result = await Process.run('open', [dmg.path]);
      if (result.exitCode != 0) throw StateError('Unable to open DMG');
      return;
    }
    final destination = Directory(p.join(dir.path, 'app-$version'));
    if (await destination.exists()) {
      throw StateError('Update directory already exists: ${destination.path}');
    }
    // Portable desktop packages retain their data/, lib/, and .app structure.
    final staging =
        await Directory(p.join(dir.path, 'opl_app_stage_')).createTemp();
    try {
      await extractArchiveSafely(package, staging);
      await staging.rename(destination.path);
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
    appInstallPath = destination.path;
    L.i('Application update extracted to ${destination.path}; quit and launch the new version.',
        tag: 'update');
  }

  Future<String?> _getEasyTierVersion() async {
    final exePath = await _getEasyTierExePath();
    if (!await File(exePath).exists()) return null;

    try {
      final result = await _runVersion(exePath, ['--version']);
      if (result.exitCode == 0) {
        final match =
            RegExp(r'(\d+\.\d+\.\d+)').firstMatch(result.stdout.toString());
        if (match != null) return match.group(1);
      }
      final helpResult = await _runVersion(exePath, ['--help']);
      if (helpResult.exitCode == 0) {
        final match =
            RegExp(r'(\d+\.\d+\.\d+)').firstMatch(helpResult.stdout.toString());
        if (match != null) return match.group(1);
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  Future<ProcessResult> _runVersion(
      String executable, List<String> args) async {
    final process = await Process.start(executable, args);
    final stdout =
        process.stdout.transform(const SystemEncoding().decoder).join();
    final stderr =
        process.stderr.transform(const SystemEncoding().decoder).join();
    try {
      final code = await process.exitCode.timeout(const Duration(seconds: 5));
      return ProcessResult(process.pid, code, await stdout, await stderr);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
      await stdout;
      await stderr;
      rethrow;
    }
  }

  Future<String> _getEasyTierExePath() async =>
      (await PlatformPaths.easyTierFile()).path;

  void _setAllStates(UpdateState state) {
    for (final c in UpdateComponent.values) {
      _states[c] = state;
    }
  }
}
