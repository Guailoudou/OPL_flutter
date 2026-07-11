import 'config_models.dart';

class ConnectionCodeResult {
  ConnectionCodeResult({required this.tunnels, this.error});

  final List<AppTunnel> tunnels;
  final String? error;

  bool get isSuccess => error == null;

  factory ConnectionCodeResult.fail(String error) {
    return ConnectionCodeResult(tunnels: [], error: error);
  }
}

class ConnectionCode {
  ConnectionCode._();

  /// Parses a connection code string into a list of AppTunnel objects.
  ///
  /// Supported formats:
  /// - Standard: `protocol:UID:remotePort:localPort` (1=tcp, 2=udp)
  /// - Simplified: `UID:remotePort` (default TCP, localPort=remotePort)
  /// - Multi-connection: separated by `;`
  static ConnectionCodeResult parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return ConnectionCodeResult.fail('连接码不能为空');
    }

    final parts = trimmed.split(';');
    final tunnels = <AppTunnel>[];

    for (var i = 0; i < parts.length; i++) {
      final part = parts[i].trim();
      if (part.isEmpty) continue;

      try {
        final tunnel = _parseSingle(part);
        tunnels.add(tunnel);
      } catch (e) {
        return ConnectionCodeResult.fail(
          '第 ${i + 1} 个连接解析失败: $e\n连接码: $part\n示例格式: 1:UID:25565:25565',
        );
      }
    }

    if (tunnels.isEmpty) {
      return ConnectionCodeResult.fail('未找到有效的连接信息');
    }

    return ConnectionCodeResult(tunnels: tunnels);
  }

  static AppTunnel _parseSingle(String part) {
    final components = part.split(':');

    if (components.length == 4) {
      // Standard format: protocol:UID:remotePort:localPort
      final protocolNum = components[0].trim();
      final uid = components[1].trim();
      final dstPort = int.tryParse(components[2].trim());
      final srcPort = int.tryParse(components[3].trim());

      if (dstPort == null || dstPort <= 0) {
        throw Exception('远程端口无效');
      }
      if (srcPort == null || srcPort <= 0) {
        throw Exception('本地端口无效');
      }
      if (uid.isEmpty) {
        throw Exception('UID 不能为空');
      }

      final protocol = protocolNum == '2' ? 'udp' : 'tcp';

      return AppTunnel(
        appName: '',
        protocol: protocol,
        underlayProtocol: '',
        punchPriority: 0,
        whitelist: '',
        srcPort: srcPort,
        peerNode: uid,
        dstPort: dstPort,
        dstHost: 'localhost',
        peerUser: '',
        relayNode: '',
        forceRelay: 0,
        enabled: 0,
      );
    } else if (components.length == 2) {
      // Simplified format: UID:remotePort
      final uid = components[0].trim();
      final port = int.tryParse(components[1].trim());

      if (port == null || port <= 0) {
        throw Exception('端口无效');
      }
      if (uid.isEmpty) {
        throw Exception('UID 不能为空');
      }

      return AppTunnel(
        appName: '',
        protocol: 'tcp',
        underlayProtocol: '',
        punchPriority: 0,
        whitelist: '',
        srcPort: port,
        peerNode: uid,
        dstPort: port,
        dstHost: 'localhost',
        peerUser: '',
        relayNode: '',
        forceRelay: 0,
        enabled: 0,
      );
    } else {
      throw Exception('格式错误，应为 protocol:UID:远程端口:本地端口 或 UID:远程端口');
    }
  }

  /// Generates a connection code string from an AppTunnel.
  ///
  /// Format: `protocol:UID:remotePort:localPort`
  static String generate(AppTunnel tunnel) {
    final protocolNum = tunnel.protocol.toLowerCase() == 'udp' ? '2' : '1';
    return '$protocolNum:${tunnel.peerNode}:${tunnel.dstPort}:${tunnel.srcPort}';
  }

  /// Generates a multi-connection code string from a list of AppTunnels.
  static String generateMulti(List<AppTunnel> tunnels) {
    return tunnels.map(generate).join(';');
  }
}
