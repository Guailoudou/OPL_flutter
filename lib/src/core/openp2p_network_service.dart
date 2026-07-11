import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../utils/logger.dart';
import 'config_models.dart';

class OpenP2PNetworkService {
  Process? _process;
  String? _networkId;
  String? _localIp;
  bool _isHost = false;
  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  Process? get process => _process;
  String? get networkId => _networkId;
  String? get localIp => _localIp;
  bool get isHost => _isHost;
  bool get isRunning => _process != null;
  Stream<String> get logStream => _logController.stream;

  Future<void> createNetwork({
    required int port,
    required String uid,
  }) async {
    if (_process != null) {
      throw Exception('OpenP2P network is already running');
    }

    try {
      final exePath = _getExecutablePath();
      if (!await File(exePath).exists()) {
        throw Exception('OpenP2P executable not found: $exePath');
      }

      final args = [
        '-s',
        'api.openp2p.cn:27183',
        '-u',
        uid,
        '-p',
        '25565:$port',
        '-tcp',
      ];

      L.i('Creating OpenP2P network on port $port', tag: 'openp2p_network');
      _process = await Process.start(exePath, args);
      _isHost = true;
      _networkId = uid;
      _localIp = '10.0.23.1';

      _monitorProcess();
      _logController.add('Network created. Your IP: 10.0.23.1');
      _logController.add('Share your UID with others to join: $uid');
    } catch (e) {
      L.e('Failed to create network', tag: 'openp2p_network', error: e);
      rethrow;
    }
  }

  Future<void> joinNetwork({
    required String hostUid,
    required int localIpLastOctet,
    required String myUid,
  }) async {
    if (_process != null) {
      throw Exception('OpenP2P network is already running');
    }

    if (localIpLastOctet < 2 || localIpLastOctet > 20) {
      throw Exception('IP last octet must be between 2 and 20');
    }

    try {
      final exePath = _getExecutablePath();
      if (!await File(exePath).exists()) {
        throw Exception('OpenP2P executable not found: $exePath');
      }

      final args = [
        '-s',
        'api.openp2p.cn:27183',
        '-u',
        myUid,
        '-p',
        '25565:25565',
        '-tcp',
        '-peer',
        hostUid,
      ];

      L.i('Joining OpenP2P network: $hostUid', tag: 'openp2p_network');
      _process = await Process.start(exePath, args);
      _isHost = false;
      _networkId = hostUid;
      _localIp = '10.0.23.$localIpLastOctet';

      _monitorProcess();
      _logController.add('Joining network...');
      _logController.add('Your IP: 10.0.23.$localIpLastOctet');
    } catch (e) {
      L.e('Failed to join network', tag: 'openp2p_network', error: e);
      rethrow;
    }
  }

  Future<void> stop() async {
    if (_process == null) return;

    try {
      L.i('Stopping OpenP2P network', tag: 'openp2p_network');
      _process!.kill();
      await _process!.exitCode;
    } catch (e) {
      L.e('Failed to stop network', tag: 'openp2p_network', error: e);
    } finally {
      _process = null;
      _networkId = null;
      _localIp = null;
      _isHost = false;
      _logController.add('Network stopped');
    }
  }

  void _monitorProcess() {
    _process!.stdout.transform(utf8.decoder).listen((data) {
      L.d('OpenP2P network stdout: $data', tag: 'openp2p_network');
      _logController.add(data.trim());

      // Parse log for connection status
      if (data.contains('LISTEN ON PORT')) {
        _logController.add('✓ Connection established');
      } else if (data.contains('ERROR') || data.contains('error')) {
        _logController.add('✗ Error: $data');
      }
    });

    _process!.stderr.transform(utf8.decoder).listen((data) {
      L.w('OpenP2P network stderr: $data', tag: 'openp2p_network');
      _logController.add('Error: ${data.trim()}');
    });

    _process!.exitCode.then((code) {
      L.i('OpenP2P network exited with code: $code', tag: 'openp2p_network');
      _process = null;
      _networkId = null;
      _localIp = null;
      _isHost = false;
      _logController.add('Network process exited with code: $code');
    });
  }

  String _getExecutablePath() {
    if (Platform.isWindows) {
      return 'openp2p.exe';
    } else {
      return 'openp2p';
    }
  }

  void dispose() {
    stop();
    _logController.close();
  }
}
