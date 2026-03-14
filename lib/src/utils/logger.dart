import '../state/log_store.dart';

class L {
  static LogStore? _logStore;

  static void init(LogStore logStore) {
    _logStore = logStore;
  }

  static void d(String message, {String tag = 'APP'}) {
    _log('D', tag, message);
  }

  static void i(String message, {String tag = 'APP'}) {
    _log('I', tag, message);
  }

  static void w(String message, {String tag = 'APP'}) {
    _log('W', tag, message);
  }

  static void e(String message, {String tag = 'APP', dynamic error, StackTrace? stackTrace}) {
    final logMessage = error != null ? '$message\nError: $error' : message;
    _log('E', tag, logMessage);
    if (stackTrace != null) {
      _logStore?.add('STACK: $stackTrace');
    }
  }

  static String _formatTime() {
    final now = DateTime.now();
    final time = now.toIso8601String().split('T')[1];
    // 格式化为 HH:mm:ss.SSS
    final parts = time.split(':');
    final seconds = parts[2].split('.')[0];
    final milliseconds = now.millisecond.toString().padLeft(3, '0');
    return '${parts[0]}:${parts[1]}:$seconds.$milliseconds';
  }

  static void _log(String level, String tag, String message) {
    final time = _formatTime();
    final logMessage = '[$time][$level/$tag] $message';
    final logStore = _logStore;
    if (logStore != null) {
      logStore.add(logMessage);
    } else {
      print(logMessage);
    }
  }
}
