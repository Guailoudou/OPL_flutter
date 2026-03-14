import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/platform_paths.dart';

class LogStore extends ChangeNotifier {
  final List<String> _lines = [];
  File? _logFile;
  bool _fileInitialized = false;
  bool _canWriteToFile = false;
  final StreamController<String> _logController = StreamController<String>.broadcast();

  List<String> get lines => List.unmodifiable(_lines);

  void Function(String line)? onNewLine;

  LogStore() {
    _initLogFile();
  }

  Future<void> _initLogFile() async {
    try {
      // 使用与核心文件和配置文件相同的 OPL 目录
      final oplDir = await PlatformPaths.configDir();
      
      print('[LogStore] Using OPL directory: ${oplDir.path}');
      
      _logFile = File(p.join(oplDir.path, 'opl.log'));
      print('[LogStore] Log file path: ${_logFile!.path}');
      
      // 检查文件是否可写
      try {
        await _logFile!.writeAsString('[${DateTime.now()}] Log file initialized\n', mode: FileMode.append);
        _canWriteToFile = true;
        print('[LogStore] ✓ Log file initialized successfully');
        print('[LogStore]   Location: ${_logFile!.path}');
      } catch (e) {
        _canWriteToFile = false;
        print('[LogStore] ✗ Cannot write to file: $e');
        print('[LogStore]   File path: ${_logFile!.path}');
        print('[LogStore]   Directory exists: ${await oplDir.exists()}');
      }
      
      _fileInitialized = true;
    } catch (e) {
      _fileInitialized = true;
      _canWriteToFile = false;
      print('[LogStore] ✗ Failed to initialize log file: $e');
    }
  }

  void add(String line) {
    // 添加到内存
    _lines.add(line);
    if (_lines.length > 5000) {
      _lines.removeRange(0, _lines.length - 5000);
    }
    
    // 通知 UI 更新
    onNewLine?.call(line);
    notifyListeners();
    
    // 广播日志流
    _logController.add(line);
    
    // 始终打印到控制台
    print(line);
    
    // 写入文件（如果可以）
    if (_canWriteToFile && _logFile != null) {
      _writeToFile(line);
    }
  }

  Future<void> _writeToFile(String line) async {
    if (_logFile == null) return;
    
    try {
      final timestamp = DateTime.now().toIso8601String();
      await _logFile!.writeAsString('[$timestamp] $line\n', mode: FileMode.append);
    } catch (e) {
      // 如果写入失败，禁用文件写入
      if (_canWriteToFile) {
        _canWriteToFile = false;
        print('[LogStore] File write failed, disabling file logging: $e');
        print('[LogStore] File path: ${_logFile!.path}');
        print('[LogStore] File exists: ${await _logFile!.exists()}');
      }
    }
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  Stream<String> get logStream => _logController.stream;

  @override
  void dispose() {
    _logController.close();
    super.dispose();
  }
}

