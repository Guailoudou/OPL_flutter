import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../utils/logger.dart';

/// Flutter <-> OpenHarmony bridge for the long-running OpenP2P core.
///
/// The channel deliberately uses the same contract as Android so the state
/// layer remains platform independent.
class OhosCoreService {
  OhosCoreService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.opl_config_manager/core');

  static Future<bool> startCore({
    required String baseDir,
    required String token,
    required int shareBandwidth,
    required int logLevel,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('startCore', {
        'baseDir': baseDir,
        'token': token,
        'shareBandwidth': shareBandwidth,
        'logLevel': logLevel,
      });
      if (result != true) {
        return false;
      }
      final coreReady = await _waitForCoreStart(baseDir);
      if (!coreReady) {
        return false;
      }

      final currentStatus = await getCoreStatus();
      if (_isState(currentStatus, 'vpn_ready')) {
        return true;
      }
      if (_isState(currentStatus, 'vpn_waiting_config')) {
        // The native core is logged in and remains online. The VPN extension
        // will create its interface when the server pushes an SD-WAN that
        // contains this node.
        return true;
      }
      if (_isState(currentStatus, 'vpn_requested') ||
          _isState(currentStatus, 'vpn_starting')) {
        return _waitForVpnReady(baseDir);
      }

      // Core startup and TUN creation are separate stages, matching the
      // ClashBox VPN extension lifecycle.
      final vpnRequested = await _requestVpn();
      if (!vpnRequested) {
        return false;
      }
      return _waitForVpnReady(baseDir);
    } catch (e) {
      L.e('Failed to start core on OpenHarmony', tag: 'ohos', error: e);
      return false;
    }
  }

  static Future<String?> getCoreStatus() async {
    try {
      return await _channel.invokeMethod<String>('getCoreStatus');
    } catch (e) {
      L.e('Failed to read core status on OpenHarmony', tag: 'ohos', error: e);
      return null;
    }
  }

  static Future<String?> getAppVersion() =>
      _channel.invokeMethod<String>('getAppVersion');

  static Future<Map<String, dynamic>> getKeepAliveOptions() async {
    final value = await _channel.invokeMethod<String>('getKeepAliveOptions');
    return jsonDecode(value ?? '{}') as Map<String, dynamic>;
  }

  static Future<bool> setKeepAlive(bool enabled,
          {bool pictureInPicture = false}) async =>
      await _channel.invokeMethod<bool>(
          pictureInPicture ? 'setPictureInPicture' : 'setBackgroundKeepAlive',
          {'enabled': enabled}) ??
      false;

  static Future<bool> _waitForCoreStart(String baseDir) async {
    final deadline = DateTime.now().add(const Duration(seconds: 35));
    String? lastState;
    String? lastMessage;

    while (DateTime.now().isBefore(deadline)) {
      final rawStatus = await getCoreStatus();
      if (rawStatus != null) {
        try {
          final status = jsonDecode(rawStatus) as Map<String, dynamic>;
          final state = status['state']?.toString();
          final message = status['message']?.toString();
          if (state != lastState || message != lastMessage) {
            L.i('OHOS core status: ${state ?? 'unknown'}${message == null ? '' : ' ($message)'}',
                tag: 'ohos');
            lastState = state;
            lastMessage = message;
          }
          if (state == 'core_started' ||
              state == 'vpn_waiting_config' ||
              state == 'vpn_ready' ||
              state == 'vpn_requested' ||
              state == 'vpn_starting') {
            final requestId = status['requestId']?.toString();
            if (await _hasVpnHandshake(baseDir, requestId)) {
              return true;
            }
          }
          if (state == 'failed') {
            return false;
          }
        } catch (e) {
          L.w('Invalid OHOS core status: $rawStatus', tag: 'ohos');
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    L.e('Timed out waiting for the OHOS VPN extension/core handshake',
        tag: 'ohos');
    return false;
  }

  static Future<bool> _requestVpn() async {
    try {
      final result = await _channel.invokeMethod<bool>('startVpn');
      if (result != true) {
        L.e('OHOS VPN interface request was rejected', tag: 'ohos');
        return false;
      }
      return true;
    } catch (e) {
      L.e('Failed to request the OHOS VPN interface', tag: 'ohos', error: e);
      return false;
    }
  }

  static Future<bool> _waitForVpnReady(String baseDir) async {
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    String? lastState;
    String? lastMessage;

    while (DateTime.now().isBefore(deadline)) {
      final rawStatus = await getCoreStatus();
      if (rawStatus != null) {
        try {
          final status = jsonDecode(rawStatus) as Map<String, dynamic>;
          final state = status['state']?.toString();
          final message = status['message']?.toString();
          if (state != lastState || message != lastMessage) {
            L.i('OHOS VPN status: ${state ?? 'unknown'}${message == null ? '' : ' ($message)'}',
                tag: 'ohos');
            lastState = state;
            lastMessage = message;
          }
          if (state == 'vpn_ready') {
            final requestId = status['requestId']?.toString();
            return _hasVpnHandshake(baseDir, requestId);
          }
          if (state == 'vpn_waiting_config') {
            final requestId = status['requestId']?.toString();
            return _hasVpnHandshake(baseDir, requestId);
          }
          if (state == 'failed' || state == 'stopped') {
            return false;
          }
        } catch (e) {
          L.w('Invalid OHOS VPN status: $rawStatus', tag: 'ohos');
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    L.e('Timed out waiting for the OHOS VPN interface', tag: 'ohos');
    return false;
  }

  static Future<bool> _hasVpnHandshake(
      String baseDir, String? requestId) async {
    try {
      final file = File(p.join(baseDir, 'vpn_ipc.lock'));
      if (!await file.exists()) {
        return false;
      }
      final value = (await file.readAsString()).trim();
      if (value.isEmpty) {
        return false;
      }
      return requestId == null || requestId.isEmpty || value == requestId;
    } catch (e) {
      L.w('Unable to read OHOS VPN handshake: $e', tag: 'ohos');
      return false;
    }
  }

  static bool _isState(String? rawStatus, String expected) {
    if (rawStatus == null) {
      return false;
    }
    try {
      final status = jsonDecode(rawStatus) as Map<String, dynamic>;
      return status['state']?.toString() == expected;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stopCore() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopCore');
      return result ?? false;
    } catch (e) {
      L.e('Failed to stop core on OpenHarmony', tag: 'ohos', error: e);
      return false;
    }
  }
}
