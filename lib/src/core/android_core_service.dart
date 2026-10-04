import 'platform_support.dart';
import 'package:flutter/services.dart';

import '../utils/logger.dart';

class AndroidCoreService {
  static const MethodChannel _channel =
      MethodChannel('com.example.opl_config_manager/core');

  static Future<bool> startCore({
    required String baseDir,
    required String token,
    required int shareBandwidth,
    required int logLevel,
  }) async {
    if (!PlatformSupport.isAndroid) {
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
    if (!PlatformSupport.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('stopCore');
      return result ?? false;
    } catch (e) {
      L.e('Failed to stop core on Android', tag: 'android', error: e);
      return false;
    }
  }

  static Future<bool> isCoreRunning() async =>
      await _channel.invokeMethod<bool>('isCoreRunning') ?? false;

  static Future<bool> installApk(String apkPath) async {
    if (!PlatformSupport.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'installApk',
        {'apkPath': apkPath},
      );
      return result ?? false;
    } catch (e) {
      L.e('Failed to open Android package installer', tag: 'android', error: e);
      rethrow;
    }
  }
}
