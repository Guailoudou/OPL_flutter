import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/android_core_service.dart';
import '../core/ohos_core_service.dart';
import '../core/config_models.dart';
import '../core/platform_paths.dart';
import '../core/platform_support.dart';
import 'log_store.dart';

class CoreRunner {
  CoreRunner({
    required this.logs,
    required this.onCoreVersionChanged,
    this.onStateChanged,
  });

  final LogStore logs;
  final void Function(String version) onCoreVersionChanged;
  final void Function()? onStateChanged;
  Process? _process;
  StreamSubscription<String>? _outSub;
  StreamSubscription<String>? _errSub;
  bool _desktopStarting = false;
  bool _androidRunning = false;
  bool _androidStarting = false;
  Timer? _androidLogTimer;
  File? _androidLogFile;
  int _androidLogOffset = 0;
  bool _readingAndroidLog = false;
  Timer? _statusTimer;
  bool _checkingStatus = false;
  bool _disposed = false;
  final List<int> _partialLine = [];

  Future<void> initialize() async {
    if (!PlatformSupport.isAndroidLike) return;
    await _refreshMobileStatus();
    _statusTimer = Timer.periodic(
        const Duration(seconds: 3), (_) => unawaited(_refreshMobileStatus()));
  }

  Future<void> _refreshMobileStatus() async {
    if (_disposed || _androidStarting || _checkingStatus) return;
    _checkingStatus = true;
    try {
      bool running;
      if (PlatformSupport.isOhos) {
        final raw = await OhosCoreService.getCoreStatus();
        final status = raw == null
            ? <String, dynamic>{}
            : jsonDecode(raw) as Map<String, dynamic>;
        final timestamp = (status['timestamp'] as num?)?.toInt() ?? 0;
        running = status['coreAlive'] == true &&
            DateTime.now().millisecondsSinceEpoch - timestamp < 40000;
      } else {
        running = await AndroidCoreService.isCoreRunning();
      }
      if (_disposed || _androidStarting || running == _androidRunning) return;
      _androidRunning = running;
      if (running) {
        await _startAndroidLogReader((await PlatformPaths.configDir()).path);
      } else {
        await _stopAndroidLogReader();
      }
      onStateChanged?.call();
    } catch (error) {
      logs.add('[core] Failed to refresh native status: $error');
    } finally {
      _checkingStatus = false;
    }
  }

  bool get isRunning =>
      _desktopStarting ||
      _androidRunning ||
      _androidStarting ||
      _process != null;

  Future<void> start(ConfigRoot config) async {
    if (isRunning) return;
    if (PlatformSupport.isAndroidLike) {
      await _startMobileCore(config);
      return;
    }
    if (!PlatformPaths.isDesktop) {
      throw UnsupportedError('当前平台仅支持界面与配置');
    }
    if (_process != null) return;

    _desktopStarting = true;
    onStateChanged?.call();
    try {
      await _startDesktopCore();
    } finally {
      _desktopStarting = false;
      if (!_disposed) onStateChanged?.call();
    }
  }

  Future<void> _startDesktopCore() async {
    final core = await PlatformPaths.coreFile();
    if (!await core.exists()) {
      throw StateError('核心文件不存在：${core.path}');
    }

    final workDir = (await PlatformPaths.configDir()).path;
    logs.add('[core] starting: ${core.path}');

    final process =
        await Process.start(core.path, const [], workingDirectory: workDir);
    _process = process;
    _outSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(logs.add);
    _errSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => logs.add('[stderr] $line'));
    unawaited(process.exitCode.then((code) {
      logs.add('[core] exited with code: $code');
      if (identical(_process, process)) _cleanup();
    }));
  }

  Future<void> _startMobileCore(ConfigRoot config) async {
    if (!PlatformSupport.isAndroidLike) return;
    if (_androidStarting || _androidRunning) return;

    final dir = await PlatformPaths.configDir();
    final dirPath = dir.path;
    // The OHOS VPN extension and the Flutter UI share this app sandbox. The
    // native core writes its log to the same directory that the reader polls.
    await Directory(p.join(dirPath, 'log')).create(recursive: true);
    _androidStarting = true;

    final platformName = PlatformSupport.isOhos ? 'ohos' : 'android';
    logs.add('[core] starting $platformName core at: $dirPath');
    await _startAndroidLogReader(dirPath);

    try {
      final success = PlatformSupport.isOhos
          ? await OhosCoreService.startCore(
              baseDir: dirPath,
              token: config.network.token.toString(),
              shareBandwidth: config.network.shareBandwidth,
              logLevel: config.logLevel,
            )
          : await AndroidCoreService.startCore(
              baseDir: dirPath,
              token: config.network.token.toString(),
              shareBandwidth: config.network.shareBandwidth,
              logLevel: config.logLevel,
            );
      if (success) {
        _androidRunning = true;
        logs.add('[core] $platformName core started via MethodChannel');
      } else {
        _androidRunning = false;
        logs.add('[core] failed to start $platformName core');
        await _stopAndroidLogReader();
        throw StateError('系统未能启动 OpenP2P 核心');
      }
    } catch (e) {
      logs.add('[core] $platformName start error: $e');
      await _stopAndroidLogReader();
      rethrow;
    } finally {
      _androidStarting = false;
    }
  }

  Future<void> stop() async {
    if (_androidStarting || _desktopStarting) {
      throw StateError('Core is still starting');
    }
    if (PlatformSupport.isAndroidLike) {
      final success = PlatformSupport.isOhos
          ? await OhosCoreService.stopCore()
          : await AndroidCoreService.stopCore();
      if (!success) throw StateError('Failed to stop native core');
      _androidRunning = false;
      await _stopAndroidLogReader();
      onStateChanged?.call();
      return;
    }
    final process = _process;
    if (process == null) return;
    if (PlatformSupport.isWindows) {
      final result =
          await Process.run('taskkill', ['/F', '/T', '/PID', '${process.pid}']);
      if (result.exitCode != 0 && identical(_process, process)) {
        throw StateError('Failed to stop core: ${result.stderr}');
      }
    } else {
      process.kill(ProcessSignal.sigterm);
    }
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode.timeout(const Duration(seconds: 5));
    }
    if (identical(_process, process)) _cleanup();
  }

  void _cleanup() {
    _process = null;
    unawaited(_outSub?.cancel());
    unawaited(_errSub?.cancel());
    _outSub = null;
    _errSub = null;
    if (!_disposed) onStateChanged?.call();
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
      final length = await file.length();
      if (length < _androidLogOffset) {
        _androidLogOffset = 0;
        _partialLine.clear();
      }
      if (length == _androidLogOffset) return;
      final reader = await file.open();
      late List<int> newBytes;
      try {
        await reader.setPosition(_androidLogOffset);
        final count = length - _androidLogOffset;
        newBytes = await reader.read(count > 256 * 1024 ? 256 * 1024 : count);
      } finally {
        await reader.close();
      }
      _androidLogOffset += newBytes.length;
      if (!identical(file, _androidLogFile) || _disposed) return;
      _partialLine.addAll(newBytes);
      var start = 0;
      for (var i = 0; i < _partialLine.length; i++) {
        if (_partialLine[i] != 10) continue;
        final line = utf8
            .decode(_partialLine.sublist(start, i), allowMalformed: true)
            .trimRight();
        if (line.isNotEmpty) logs.add('[core/native] $line');
        start = i + 1;
      }
      _partialLine.removeRange(0, start);
      if (_partialLine.length > 256 * 1024) _partialLine.clear();
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
    _partialLine.clear();
  }

  void dispose() {
    _disposed = true;
    _statusTimer?.cancel();
    _androidLogTimer?.cancel();
    _androidLogTimer = null;
    _androidLogFile = null;
    unawaited(_outSub?.cancel());
    unawaited(_errSub?.cancel());
  }
}
