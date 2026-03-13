import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../core/android_core_service.dart';
import '../core/config_models.dart';
import '../core/platform_paths.dart';
import 'log_store.dart';

class CoreRunner {
  CoreRunner({
    required this.logs,
    required this.onCoreVersionChanged,
  });

  final LogStore logs;
  final void Function(String version) onCoreVersionChanged;
  Process? _process;
  StreamSubscription<String>? _outSub;
  StreamSubscription<String>? _errSub;

  bool get isRunning => _process != null;

  static const String _releasesUrl =
      'https://file.gldhn.top/file/openp2p_releases/releases.json';
  static const String _filesBaseUrl =
      'https://file.gldhn.top/file/openp2p_releases';

  Future<CoreRelease?> fetchLatestRelease() async {
    if (!PlatformPaths.isDesktop) return null;
    final resp = await http.get(Uri.parse(_releasesUrl));
    if (resp.statusCode != 200) {
      throw StateError('获取 releases.json 失败：HTTP ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw StateError('releases.json 格式错误');
    }
    final platform = Platform.isWindows
        ? 'windows'
        : Platform.isLinux
            ? 'linux'
            : Platform.isMacOS
                ? 'darwin'
                : null;
    if (platform == null) return null;

    const arch = 'amd64'; // 假定 64 位桌面环境
    final candidates = decoded.whereType<Map>().map((e) {
      final m = e.cast<String, dynamic>();
      return CoreRelease.fromJson(m);
    }).where((r) => r.platform == platform && r.architecture == arch);

    return candidates.isNotEmpty ? candidates.first : null;
  }

  Future<void> ensureCorePresent() async {
    final core = await PlatformPaths.coreFile();
    if (await core.exists()) return;

    final release = await fetchLatestRelease();
    if (release == null) {
      throw StateError('未在 releases.json 中找到当前平台的核心文件');
    }

    final url = Uri.parse('$_filesBaseUrl/${release.filename}');
    logs.add('[core] downloading: $url');
    final resp = await http.get(url);
    if (resp.statusCode != 200) {
      throw StateError('核心下载失败：HTTP ${resp.statusCode}');
    }

    final bytes = resp.bodyBytes;
    final digest = sha256.convert(bytes).toString();
    if (digest.toLowerCase() != release.sha256.toLowerCase()) {
      throw StateError('核心文件校验失败（sha256 不匹配）');
    }

    final dir = await PlatformPaths.configDir();
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
      throw StateError('解压核心失败：未找到可执行文件');
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

    logs.add('[core] downloaded: ${core.path}');
    onCoreVersionChanged(release.version);
  }

  Future<void> start(ConfigRoot config) async {
    if (Platform.isAndroid) {
      await _startAndroid(config);
      return;
    }
    if (!PlatformPaths.isDesktop) {
      logs.add('[core] mobile start reserved (not implemented)');
      return;
    }
    if (_process != null) return;

    final core = await PlatformPaths.coreFile();
    if (!await core.exists()) {
      throw StateError('核心文件不存在：${core.path}');
    }

    final workDir = (await PlatformPaths.configDir()).path;
    logs.add('[core] starting: ${core.path}');

    if (Platform.isWindows) {
      await _runAsAdmin(core.path, workDir);
    } else {
      _process = await Process.start(
        core.path,
        const [],
        workingDirectory: workDir,
        runInShell: true,
      );

      _outSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => logs.add(line));
      _errSub = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => logs.add('[stderr] $line'));

      unawaited(_process!.exitCode.then((code) {
        logs.add('[core] exited with code: $code');
        _cleanup();
      }));
    }
  }

  Future<void> _runAsAdmin(String exePath, String workingDir) async {
    if (!Platform.isWindows) return;
    
    logs.add('[core] starting core: ${exePath}');
    
    try {
      // Start core directly without admin elevation popup
      // The core should work without admin rights in most cases
      _process = await Process.start(
        exePath,
        const [],
        workingDirectory: workingDir,
        runInShell: true,
      );

      _outSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => logs.add(line));
      _errSub = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => logs.add('[stderr] $line'));

      unawaited(_process!.exitCode.then((code) {
        logs.add('[core] exited with code: $code');
        _cleanup();
      }));
      
      logs.add('[core] started successfully');
    } catch (e) {
      logs.add('[core] start failed: $e');
      rethrow;
    }
  }

  Future<void> _startAndroid(ConfigRoot config) async {
    if (!Platform.isAndroid) return;
    
    final dir = await PlatformPaths.configDir();
    final dirPath = dir.path;
    
    logs.add('[core] starting android core at: $dirPath');
    
    try {
      final success = await AndroidCoreService.startCore(dirPath);
      if (success) {
        logs.add('[core] android core started via MethodChannel');
      } else {
        logs.add('[core] failed to start android core');
      }
    } catch (e) {
      logs.add('[core] android start error: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    final p = _process;
    if (p == null) return;
    logs.add('[core] stopping...');
    p.kill(ProcessSignal.sigterm);
    await Future.delayed(const Duration(milliseconds: 300));
    if (_process != null) {
      p.kill(ProcessSignal.sigkill);
    }
    _cleanup();
  }

  void _cleanup() {
    _process = null;
    unawaited(_outSub?.cancel());
    unawaited(_errSub?.cancel());
    _outSub = null;
    _errSub = null;
  }
}

class CoreRelease {
  CoreRelease({
    required this.platform,
    required this.architecture,
    required this.version,
    required this.filename,
    required this.sha256,
  });

  final String platform;
  final String architecture;
  final String version;
  final String filename;
  final String sha256;

  factory CoreRelease.fromJson(Map<String, dynamic> json) {
    return CoreRelease(
      platform: json['platform'] as String? ?? '',
      architecture: json['architecture'] as String? ?? '',
      version: json['version'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      sha256: json['sha256'] as String? ?? '',
    );
  }
}

