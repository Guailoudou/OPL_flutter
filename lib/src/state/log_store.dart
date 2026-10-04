import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../core/platform_paths.dart';
import '../core/platform_support.dart';

class LogStore extends ChangeNotifier {
  LogStore({bool persist = true}) {
    if (persist && !PlatformSupport.isWeb) _initialize();
  }

  final List<String> _lines = [];
  final _logController = StreamController<String>.broadcast();
  File? _logFile;
  bool _disposed = false;
  Future<void> _writes = Future<void>.value();
  void Function(String line)? onNewLine;

  List<String> get lines => List.unmodifiable(_lines);
  Stream<String> get logStream => _logController.stream;

  Future<void> _initialize() async {
    try {
      final dir = await PlatformPaths.configDir();
      final file = File(p.join(dir.path, 'log', 'opl.log'));
      await file.parent.create(recursive: true);
      if (!_disposed) _logFile = file;
    } catch (error) {
      debugPrint('File logging unavailable: $error');
    }
  }

  void add(String line) {
    if (_disposed) return;
    _lines.add(line);
    if (_lines.length > 5000) _lines.removeRange(0, _lines.length - 5000);
    onNewLine?.call(line);
    notifyListeners();
    _logController.add(line);
    debugPrint(line);
    final file = _logFile;
    if (file != null) {
      _writes = _writes.then((_) async {
        await file.writeAsString(
            '[${DateTime.now().toIso8601String()}] $line\n',
            mode: FileMode.append);
      }).catchError((Object error) {
        _logFile = null;
        debugPrint('File logging disabled: $error');
      });
    }
  }

  void clear() {
    if (_disposed) return;
    _lines.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    onNewLine = null;
    unawaited(_logController.close());
    super.dispose();
  }
}
