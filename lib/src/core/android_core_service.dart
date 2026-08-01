import 'dart:io';
import 'package:flutter/services.dart';

import '../utils/logger.dart';

class AndroidCoreService {
  static const MethodChannel _channel = MethodChannel('com.example.opl_config_manager/core');

  static Future<bool> startCore({
    required String baseDir,
    required String token,
    required int shareBandwidth,
    required int logLevel,
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('startCore', {
        'baseDir': baseDir,
        'token': token,
        'shareBandwidth': shareBandwidth,
        'logLevel': logLevel,
      });
      return result ?? false;
    } catch (e) {
      L.e('Failed to start core on Android', tag: 'android', error: e);
      return false;
    }
  }

  static Future<bool> stopCore() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('stopCore');
      return result ?? false;
    } catch (e) {
      L.e('Failed to stop core on Android', tag: 'android', error: e);
      return false;
    }
  }
}
