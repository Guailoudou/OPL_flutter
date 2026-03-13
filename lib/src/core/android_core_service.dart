import 'dart:io';
import 'package:flutter/services.dart';

class AndroidCoreService {
  static const MethodChannel _channel = MethodChannel('com.example.opl_config_manager/core');

  static Future<bool> startCore(String baseDir) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('startCore', {
        'baseDir': baseDir,
      });
      return result ?? false;
    } catch (e) {
      print('Failed to start core on Android: $e');
      return false;
    }
  }
}
