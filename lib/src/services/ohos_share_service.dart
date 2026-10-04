import 'package:flutter/services.dart';

/// Native OpenHarmony system sharing bridge.
class OhosShareService {
  OhosShareService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.opl_config_manager/core');

  static Future<bool> shareFile(String path) async {
    try {
      final result = await _channel.invokeMethod<bool>('shareFile', {
        'path': path,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
