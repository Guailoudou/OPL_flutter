import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/android_core_service.dart';
import '../core/config_models.dart';
import '../core/platform_paths.dart';
import '../core/process_monitor.dart';
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
  bool _androidRunning = false;
  bool _androidStarting = false;
  Timer? _androidLogTimer;
  File? _androidLogFile;
  int _androidLogOffset = 0;
  bool _readingAndroidLog = false;

  bool get isRunning =>
      _androidRunning ||
      _androidStarting ||
      _process != null ||
      (_processManager?.isRunning ?? false);

  Future<void> start(ConfigRoot config) async {
    if (isRunning) return;
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
    if (_androidStarting || _androidRunning) return;

    final dir = await PlatformPaths.configDir();
    final dirPath = dir.path;
    _androidStarting = true;

    logs.add('[core] starting android core at: $dirPath');
    await _startAndroidLogReader(dirPath);

    try {
      final success = await AndroidCoreService.startCore(
        baseDir: dirPath,
        token: config.network.token.toString(),
        shareBandwidth: config.network.shareBandwidth,
        logLevel: config.logLevel,
      );
      if (success) {
        _androidRunning = true;
        logs.add('[core] android core started via MethodChannel');
      } else {
        _androidRunning = false;
        logs.add('[core] failed to start android core');
        await _stopAndroidLogReader();
      }
    } catch (e) {
      logs.add('[core] android start error: $e');
      await _stopAndroidLogReader();
      rethrow;
    } finally {
      _androidStarting = false;
    }
  }

  Future<void> stop() async {
    if (Platform.isAndroid) {
      await AndroidCoreService.stopCore();
      _androidRunning = false;
      await _stopAndroidLogReader();
      return;
    }
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
        final stillRunning =
            checkResult.stdout.toString().contains(pid.toString());
        if (stillRunning) {
          logs.add(
              '[core] WARNING: Process $pid still running, trying fallback...');
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

  Future<void> _startAndroidLogReader(String baseDir) async {
    await _stopAndroidLogReader();
    _androidLogFile = File(
      '$baseDir${Platform.pathSeparator}log${Platform.pathSeparator}openp2p.log',
    );
    if (await _androidLogFile!.exists()) {
      _androidLogOffset = await _androidLogFile!.length();
    }
    _androidLogTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => unawaited(_readAndroidLog()),
    );
  }

  Future<void> _readAndroidLog() async {
    if (_readingAndroidLog || _androidLogFile == null) return;
    _readingAndroidLog = true;
    try {
      final file = _androidLogFile!;
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      if (bytes.length < _androidLogOffset) {
        _androidLogOffset = 0;
      }
      if (bytes.length == _androidLogOffset) return;

      final newBytes = bytes.sublist(_androidLogOffset);
      _androidLogOffset = bytes.length;
      final text = utf8.decode(newBytes, allowMalformed: true);
      for (final line in const LineSplitter().convert(text)) {
        if (line.trim().isNotEmpty) {
          logs.add('[core/native] $line');
        }
      }
    } catch (_) {
      // Core log may be rotated while it is being read; retry on next tick.
    } finally {
      _readingAndroidLog = false;
    }
  }

  Future<void> _stopAndroidLogReader() async {
    _androidLogTimer?.cancel();
    _androidLogTimer = null;
    await _readAndroidLog();
    _androidLogFile = null;
    _androidLogOffset = 0;
  }
}
