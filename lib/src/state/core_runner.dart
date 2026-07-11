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
import '../core/process_monitor.dart';
import '../core/url_config.dart';
import 'log_store.dart';
import 'process_manager.dart';

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
  ProcessManager? _processManager;
  ProcessMonitor? _processMonitor;

  bool get isRunning => _process != null || (_processManager?.isRunning ?? false);

  Future<CoreRelease?> fetchLatestRelease() async {
    if (!PlatformPaths.isDesktop) return null;
    final resp = await http.get(Uri.parse(UrlConfig.releasesApiUrl));
    if (resp.statusCode != 200) {
      throw StateError('获取 releases 失败：HTTP ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('releases 格式错误');
    }
    final coreData = decoded['core'];
    if (coreData is! Map<String, dynamic>) {
      throw StateError('releases.core 格式错误');
    }
    final platform = Platform.isWindows
        ? 'windows'
        : Platform.isLinux
            ? 'linux'
            : Platform.isMacOS
                ? 'macos'
                : null;
    if (platform == null) return null;

    final platformData = coreData[platform];
    if (platformData is! Map<String, dynamic>) {
      return null;
    }

    return CoreRelease.fromJson(platformData, platform);
  }

  Future<void> ensureCorePresent() async {
    final core = await PlatformPaths.coreFile();
    if (await core.exists()) return;

    final release = await fetchLatestRelease();
    if (release == null) {
      throw StateError('未在 releases.json 中找到当前平台的核心文件');
    }

    final url = Uri.parse(release.url);
    logs.add('[core] downloading: $url');
    final resp = await http.get(url);
    if (resp.statusCode != 200) {
      throw StateError('核心下载失败：HTTP ${resp.statusCode}');
    }

    final bytes = resp.bodyBytes;
    // 跳过 placeholder_hash 的校验
    if (release.sha256.isNotEmpty && release.sha256 != 'placeholder_hash') {
      final digest = sha256.convert(bytes).toString();
      if (digest.toLowerCase() != release.sha256.toLowerCase()) {
        throw StateError('核心文件校验失败（sha256 不匹配）');
      }
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
    
    final pid = p.pid;
    logs.add('[core] stopping... (PID: $pid)');
    
    try {
      if (Platform.isWindows) {
        // Kill process tree on Windows using taskkill with /T flag
        // /T - Terminate the specified process and any child processes
        // /F - Forcefully terminate
        final result = await Process.run(
          'taskkill', 
          ['/F', '/T', '/PID', pid.toString()],
          runInShell: true,
        );
        logs.add('[core] taskkill output: ${result.stdout}');
        if (result.stderr.toString().isNotEmpty) {
          logs.add('[core] taskkill error: ${result.stderr}');
        }
        
        // Wait and verify process is killed
        await Future.delayed(const Duration(milliseconds: 1000));
        
        // Check if process still exists
        final checkResult = await Process.run(
          'tasklist',
          ['/FI', 'PID eq $pid'],
          runInShell: true,
        );
        final stillRunning = checkResult.stdout.toString().contains(pid.toString());
        if (stillRunning) {
          logs.add('[core] WARNING: Process $pid still running, trying fallback...');
          // Fallback: kill by process name
          await Process.run(
            'taskkill', 
            ['/F', '/IM', 'openp2p-opl.exe'],
            runInShell: true,
          );
          logs.add('[core] killed by process name');
        } else {
          logs.add('[core] process $pid successfully killed');
        }
      } else {
        // Use signals on Unix-like systems
        p.kill(ProcessSignal.sigterm);
        await Future.delayed(const Duration(milliseconds: 300));
        if (_process != null) {
          p.kill(ProcessSignal.sigkill);
        }
      }
    } catch (e) {
      logs.add('[core] failed to stop core: $e');
      // Fallback: try to kill by process name
      if (Platform.isWindows) {
        try {
          await Process.run(
            'taskkill', 
            ['/F', '/IM', 'openp2p-opl.exe'],
            runInShell: true,
          );
          logs.add('[core] killed by process name (fallback)');
        } catch (_) {
          // Ignore
        }
      }
    } finally {
      _cleanup();
    }
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
    required this.version,
    required this.url,
    required this.filename,
    required this.sha256,
  });

  final String platform;
  final String version;
  final String url;
  final String filename;
  final String sha256;

  factory CoreRelease.fromJson(Map<String, dynamic> json, String platform) {
    return CoreRelease(
      platform: platform,
      version: json['version'] as String? ?? '',
      url: json['url'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      sha256: json['hash'] as String? ?? '',
    );
  }
}

