import 'dart:async';
import 'dart:io';

import '../utils/logger.dart';

class ProcessMonitor {
  Timer? _monitorTimer;
  int? _monitoredPid;
  final Duration checkInterval;
  final void Function(bool isAlive)? onStatusChanged;

  ProcessMonitor({
    this.checkInterval = const Duration(seconds: 5),
    this.onStatusChanged,
  });

  void startMonitoring(int pid) {
    _monitoredPid = pid;
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(checkInterval, (_) async {
      if (_monitoredPid == null) return;

      final isAlive = await _isProcessAlive(_monitoredPid!);
      onStatusChanged?.call(isAlive);

      if (!isAlive) {
        L.w('Monitored process $_monitoredPid is no longer alive', tag: 'process_monitor');
        stopMonitoring();
      }
    });
  }

  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _monitoredPid = null;
  }

  Future<bool> _isProcessAlive(int pid) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run(
          'tasklist',
          ['/FI', 'PID eq $pid'],
          runInShell: true,
        );
        return result.stdout.toString().contains(pid.toString());
      } else {
        final result = await Process.run(
          'kill',
          ['-0', pid.toString()],
          runInShell: true,
        );
        return result.exitCode == 0;
      }
    } catch (e) {
      L.e('Failed to check process status', tag: 'process_monitor', error: e);
      return false;
    }
  }

  void dispose() {
    stopMonitoring();
  }
}
