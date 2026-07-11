import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'platform_paths.dart';
import '../utils/logger.dart';

enum NetworkRole {
  none,
  host,
  client,
}

class NetworkNode {
  final String hostname;
  final String ip;
  final int latency;
  final bool isLocal;
  final int recvBytes;
  final int sentBytes;
  final String tunnelProto;
  final String natType;
  final String id;
  final String version;

  NetworkNode({
    required this.hostname,
    required this.ip,
    required this.latency,
    required this.isLocal,
    required this.recvBytes,
    required this.sentBytes,
    this.tunnelProto = '',
    this.natType = '',
    this.id = '',
    this.version = '',
  });

  factory NetworkNode.fromJson(Map<String, dynamic> json) {
    return NetworkNode(
      hostname: json['hostname'] as String? ?? '',
      ip: json['ip'] as String? ?? '',
      latency: json['latency'] as int? ?? 0,
      isLocal: json['is_local'] as bool? ?? false,
      recvBytes: json['recv_bytes'] as int? ?? 0,
      sentBytes: json['sent_bytes'] as int? ?? 0,
    );
  }
}

class EasyTierService {
  Process? _process;
  NetworkRole _role = NetworkRole.none;
  String? _networkName;
  String? _localIp;
  final List<NetworkNode> _nodes = [];
  final StreamController<List<NetworkNode>> _nodesController =
      StreamController<List<NetworkNode>>.broadcast();

  void Function(String version)? onVersionChanged;

  Process? get process => _process;
  NetworkRole get role => _role;
  String? get networkName => _networkName;
  String? get localIp => _localIp;
  List<NetworkNode> get nodes => List.unmodifiable(_nodes);
  Stream<List<NetworkNode>> get nodesStream => _nodesController.stream;
  bool get isRunning => _process != null;
  bool get isHost => _role == NetworkRole.host;

  Future<void> createNetwork({
    required String nodeServer,
    required String networkName,
  }) async {
    if (_process != null) {
      throw Exception('EasyTier is already running');
    }

    try {
      final exePath = await _getExecutablePath();
      if (!await File(exePath).exists()) {
        throw StateError('EasyTier 未安装，请先设置页下载安装');
      }

      final args = [
        '-d',
        '--network-name',
        networkName,
        '--peers',
        nodeServer,
      ];

      L.i('Starting EasyTier as host: $networkName', tag: 'easytier');
      _process = await Process.start(exePath, args);
      _role = NetworkRole.host;
      _networkName = networkName;
      _localIp = null;

      _monitorProcess();
      _startNodeDiscovery();
    } catch (e) {
      L.e('Failed to create network', tag: 'easytier', error: e);
      rethrow;
    }
  }

  Future<void> joinNetwork({
    required String nodeServer,
    required String networkName,
  }) async {
    if (_process != null) {
      throw Exception('EasyTier is already running');
    }

    try {
      final exePath = await _getExecutablePath();
      if (!await File(exePath).exists()) {
        throw StateError('EasyTier 未安装，请先设置页下载安装');
      }

      final args = [
        '--network-name',
        networkName,
        '--peers',
        nodeServer,
      ];

      L.i('Joining EasyTier network: $networkName', tag: 'easytier');
      _process = await Process.start(exePath, args);
      _role = NetworkRole.client;
      _networkName = networkName;
      _localIp = null;

      _monitorProcess();
      _startNodeDiscovery();
    } catch (e) {
      L.e('Failed to join network', tag: 'easytier', error: e);
      rethrow;
    }
  }

  Future<void> stop() async {
    if (_process == null) return;

    try {
      L.i('Stopping EasyTier', tag: 'easytier');
      _process!.kill();
      await _process!.exitCode;
    } catch (e) {
      L.e('Failed to stop EasyTier', tag: 'easytier', error: e);
    } finally {
      _process = null;
      _role = NetworkRole.none;
      _networkName = null;
      _localIp = null;
      _nodes.clear();
      _nodesController.add(_nodes);
    }
  }

  void _monitorProcess() {
    _process!.stdout.transform(utf8.decoder).listen((data) {
      L.d('EasyTier stdout: $data', tag: 'easytier');
    });

    _process!.stderr.transform(utf8.decoder).listen((data) {
      L.w('EasyTier stderr: $data', tag: 'easytier');
    });

    _process!.exitCode.then((code) {
      L.i('EasyTier exited with code: $code', tag: 'easytier');
      _process = null;
      _role = NetworkRole.none;
      _networkName = null;
      _localIp = null;
      _nodes.clear();
      _nodesController.add(_nodes);
    });
  }

  void _startNodeDiscovery() {
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_process == null) {
        timer.cancel();
        return;
      }

      try {
        await _refreshNodes();
      } catch (e) {
        L.e('Failed to refresh nodes', tag: 'easytier', error: e);
      }
    });
  }

  Future<void> _refreshNodes() async {
    if (_process == null) return;

    try {
      final cliPath = await _getCliPath();
      if (!await File(cliPath).exists()) {
        L.w('easytier-cli not found at: $cliPath', tag: 'easytier');
        return;
      }

      final result = await Process.run(cliPath, ['peer']);
      if (result.exitCode != 0) {
        L.w('easytier-cli failed: ${result.stderr}', tag: 'easytier');
        return;
      }

      final output = result.stdout.toString();
      final nodes = _parseNodeList(output);
      _nodes
        ..clear()
        ..addAll(nodes);
      _nodesController.add(List<NetworkNode>.from(_nodes));

      // 更新本机 IP（第一个节点）
      if (nodes.isNotEmpty && nodes.first.ip.isNotEmpty) {
        _localIp = nodes.first.ip;
      }
    } catch (e) {
      L.e('Failed to refresh nodes', tag: 'easytier', error: e);
    }
  }

  Future<String> _getCliPath() async {
    final configDir = await PlatformPaths.configDir();
    final cliName = Platform.isWindows ? 'easytier-cli.exe' : 'easytier-cli';
    final subfolder = _getPlatformSubfolder();
    return p.join(configDir.path, subfolder, cliName);
  }

  List<NetworkNode> _parseNodeList(String output) {
    final nodes = <NetworkNode>[];

    final lines = output
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.contains('|') && !l.startsWith('|-'))
        .toList();

    if (lines.isEmpty) return nodes;

    final headers = _splitTableLine(lines[0]);
    final headerMap = <String, int>{};
    for (var i = 0; i < headers.length; i++) {
      headerMap[headers[i]] = i;
    }

    for (var i = 1; i < lines.length; i++) {
      final cells = _splitTableLine(lines[i]);
      if (cells.isEmpty) continue;

      try {
        final ip = _safeGet(cells, headerMap['ipv4'] ?? -1).replaceAll('/24', '');
        final hostname = _safeGet(cells, headerMap['hostname'] ?? -1);
        final cost = _safeGet(cells, headerMap['cost'] ?? -1);
        final latMs = _safeGet(cells, headerMap['lat(ms)'] ?? -1);
        final rxBytes = _safeGet(cells, headerMap['rx'] ?? -1);
        final txBytes = _safeGet(cells, headerMap['tx'] ?? -1);
        final tunnelProto = _safeGet(cells, headerMap['tunnel'] ?? -1);
        final natType = _safeGet(cells, headerMap['NAT'] ?? -1);
        final version = _safeGet(cells, headerMap['version'] ?? -1);

        // 过滤掉没有 IP 的节点（服务器信息）
        if (ip.isEmpty || hostname.isEmpty) continue;

        final isLocal = cost.toLowerCase() == 'local';

        nodes.add(NetworkNode(
          ip: ip,
          hostname: hostname,
          latency: _parseLatency(latMs),
          isLocal: isLocal,
          recvBytes: _parseBytes(rxBytes),
          sentBytes: _parseBytes(txBytes),
          tunnelProto: tunnelProto,
          natType: natType,
          version: version,
        ));
      } catch (e) {
        L.w('Failed to parse node line: ${lines[i]}', tag: 'easytier');
      }
    }

    return nodes;
  }

  List<String> _splitTableLine(String line) {
    final parts = line.split('|');
    // 去掉首尾空元素（行首行尾的 | 产生的空串）
    if (parts.isNotEmpty && parts.first.trim().isEmpty) {
      parts.removeAt(0);
    }
    if (parts.isNotEmpty && parts.last.trim().isEmpty) {
      parts.removeLast();
    }
    return parts.map((s) => s.trim()).toList();
  }

  String _safeGet(List<String> cells, int index) {
    if (index < 0 || index >= cells.length) return '';
    return cells[index];
  }

  int _parseLatency(String value) {
    if (value.isEmpty) return 0;
    return double.tryParse(value)?.round() ?? 0;
  }

  int _parseBytes(String value) {
    if (value.isEmpty) return 0;
    final lower = value.toLowerCase();
    final numPart = double.tryParse(lower.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (numPart == null) return 0;
    if (lower.endsWith('kb')) return (numPart * 1024).round();
    if (lower.endsWith('mb')) return (numPart * 1024 * 1024).round();
    if (lower.endsWith('gb')) return (numPart * 1024 * 1024 * 1024).round();
    return numPart.round();
  }

  Future<String> _getExecutablePath() async {
    final configDir = await PlatformPaths.configDir();
    final exeName = Platform.isWindows ? 'easytier-core.exe' : 'easytier-core';
    final subfolder = _getPlatformSubfolder();
    return p.join(configDir.path, subfolder, exeName);
  }

  String _getPlatformSubfolder() {
    if (Platform.isWindows) return 'easytier-windows-x86_64';
    if (Platform.isLinux) return 'easytier-linux-x86_64';
    if (Platform.isMacOS) return 'easytier-macos';
    return 'easytier-unknown';
  }

  Future<bool> isEasyTierInstalled() async {
    final exePath = await _getExecutablePath();
    return await File(exePath).exists();
  }

  Future<String?> getEasyTierVersion() async {
    if (!await isEasyTierInstalled()) return null;

    try {
      final exePath = await _getExecutablePath();
      // 尝试 --version 参数
      final result = await Process.run(exePath, ['--version']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        // 解析版本号，例如 "easytier-core 2.6.4" 或 "2.6.4"
        final match = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(output);
        if (match != null) {
          return match.group(1);
        }
      }
      // 如果 --version 失败，尝试从 --help 输出中解析
      final helpResult = await Process.run(exePath, ['--help']);
      if (helpResult.exitCode == 0) {
        final output = helpResult.stdout.toString();
        final match = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(output);
        if (match != null) {
          return match.group(1);
        }
      }
    } catch (e) {
      L.e('Failed to get EasyTier version', tag: 'easytier', error: e);
    }
    return null;
  }

  void dispose() {
    stop();
    _nodesController.close();
  }
}
