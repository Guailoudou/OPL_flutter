import '../core/platform_support.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../utils/logger.dart';

enum ProcessState {
  idle,
  starting,
  running,
  stopping,
  crashed,
}

class ProcessOutput {
  final String line;
  final bool isError;
  final DateTime timestamp;

  ProcessOutput({
    required this.line,
    required this.isError,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ProcessManager {
  Process? _process;
  ProcessState _state = ProcessState.idle;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  Timer? _restartTimer;
  Timer? _keepAliveTimer;
  int _restartCount = 0;
  static const int maxRestarts = 3;
  static const Duration restartDelay = Duration(seconds: 2);
  static const Duration keepAliveInterval = Duration(seconds: 30);

  final StreamController<ProcessOutput> _outputController =
      StreamController<ProcessOutput>.broadcast();
  final StreamController<ProcessState> _stateController =
      StreamController<ProcessState>.broadcast();

  Stream<ProcessOutput> get outputStream => _outputController.stream;
  Stream<ProcessState> get stateStream => _stateController.stream;
  ProcessState get state => _state;
  bool get isRunning => _state == ProcessState.running;
  int? get pid => _process?.pid;

  void _setState(ProcessState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  Future<void> start({
    required String executable,
    List<String> arguments = const [],
    String? workingDirectory,
    bool autoRestart = true,
    bool enableKeepAlive = true,
  }) async {
    if (_process != null) {
      L.w('Process already running', tag: 'process_manager');
      return;
    }

    _setState(ProcessState.starting);
    _restartCount = 0;

    try {
      await _launchProcess(
        executable: executable,
        arguments: arguments,
        workingDirectory: workingDirectory,
        autoRestart: autoRestart,
        enableKeepAlive: enableKeepAlive,
      );
    } catch (e) {
      L.e('Failed to start process', tag: 'process_manager', error: e);
      _setState(ProcessState.idle);
      rethrow;
    }
  }

  Future<void> _launchProcess({
    required String executable,
    required List<String> arguments,
    String? workingDirectory,
    required bool autoRestart,
    required bool enableKeepAlive,
  }) async {
    _process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: true,
    );

    L.i('Process started: PID ${_process!.pid}', tag: 'process_manager');
    _setState(ProcessState.running);

    _stdoutSub = _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      _outputController.add(ProcessOutput(line: line, isError: false));
      _handleLogLine(line);
    });

    _stderrSub = _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      _outputController
          .add(ProcessOutput(line: '[stderr] $line', isError: true));
    });

    unawaited(_process!.exitCode.then((code) {
      L.i('Process exited with code: $code', tag: 'process_manager');
      _cleanup();

      if (code != 0 && autoRestart && _restartCount < maxRestarts) {
        _setState(ProcessState.crashed);
        L.w(
          'Process crashed, scheduling restart (${_restartCount + 1}/$maxRestarts)',
          tag: 'process_manager',
        );
        _restartTimer = Timer(restartDelay, () {
          _restartCount++;
          _launchProcess(
            executable: executable,
            arguments: arguments,
            workingDirectory: workingDirectory,
            autoRestart: autoRestart,
            enableKeepAlive: enableKeepAlive,
          );
        });
      } else {
        _setState(ProcessState.idle);
      }
    }));

    if (enableKeepAlive) {
      _startKeepAlive();
    }
  }

  void _handleLogLine(String line) {
    // Parse log for tunnel status updates
    if (line.contains('autorunApp start')) {
      L.i('Core program started successfully', tag: 'process_manager');
    } else if (line.contains('autorunApp end')) {
      L.w('Core program offline', tag: 'process_manager');
    } else if (line.contains('LISTEN ON PORT') && line.contains('START')) {
      L.i('Tunnel connection established', tag: 'process_manager');
    } else if (line.contains('LISTEN ON PORT') && line.contains('END')) {
      L.w('Tunnel disconnected', tag: 'process_manager');
    } else if (line.contains('ERROR P2PNetwork login error')) {
      L.e('Network login error, will restart', tag: 'process_manager');
    } else if (line.contains('Only one usage of each socket address')) {
      L.e('Port conflict detected', tag: 'process_manager');
    } else if (line.contains('no such host')) {
      L.e('DNS or network error', tag: 'process_manager');
    } else if (line.contains('peer offline')) {
      L.w('Peer is offline', tag: 'process_manager');
    } else if (line.contains('NAT type:2')) {
      L.w('Symmetric NAT detected, may affect connection',
          tag: 'process_manager');
    } else if (line.contains('login ok')) {
      L.i('Login successful', tag: 'process_manager');
    }
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(keepAliveInterval, (_) {
      if (_process != null && _state == ProcessState.running) {
        L.d('Keepalive check', tag: 'process_manager');
      }
    });
  }

  Future<void> stop() async {
    final p = _process;
    if (p == null) return;

    _setState(ProcessState.stopping);
    _restartTimer?.cancel();
    _keepAliveTimer?.cancel();

    final pid = p.pid;
    L.i('Stopping process: PID $pid', tag: 'process_manager');

    try {
      if (PlatformSupport.isWindows) {
        final result = await Process.run(
          'taskkill',
          ['/F', '/T', '/PID', pid.toString()],
          runInShell: true,
        );
        L.d('taskkill output: ${result.stdout}', tag: 'process_manager');

        await Future.delayed(const Duration(milliseconds: 1000));

        final checkResult = await Process.run(
          'tasklist',
          ['/FI', 'PID eq $pid'],
          runInShell: true,
        );
        final stillRunning =
            checkResult.stdout.toString().contains(pid.toString());
        if (stillRunning) {
          L.w('Process still running, trying fallback', tag: 'process_manager');
          await Process.run(
            'taskkill',
            ['/F', '/IM', 'openp2p-opl.exe'],
            runInShell: true,
          );
        }
      } else {
        p.kill(ProcessSignal.sigterm);
        await Future.delayed(const Duration(milliseconds: 300));
        if (_process != null) {
          p.kill(ProcessSignal.sigkill);
        }
      }
    } catch (e) {
      L.e('Failed to stop process', tag: 'process_manager', error: e);
      if (PlatformSupport.isWindows) {
        try {
          await Process.run(
            'taskkill',
            ['/F', '/IM', 'openp2p-opl.exe'],
            runInShell: true,
          );
        } catch (_) {}
      }
    } finally {
      _cleanup();
      _setState(ProcessState.idle);
    }
  }

  void _cleanup() {
    _process = null;
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  void dispose() {
    stop();
    _restartTimer?.cancel();
    _outputController.close();
    _stateController.close();
  }
}
