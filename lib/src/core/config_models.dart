class ConfigRoot {
  ConfigRoot({
    required this.network,
    required this.apps,
    required this.logLevel,
  });

  final NetworkConfig network;
  final List<AppTunnel> apps;
  final int logLevel;

  static ConfigRoot defaults() {
    return ConfigRoot(
      network: NetworkConfig.defaults(),
      apps: <AppTunnel>[],
      logLevel: 1,
    );
  }

  factory ConfigRoot.fromJson(Map<String, dynamic> json) {
    final network = NetworkConfig.fromJson(
      (json['Network'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final appsJson = (json['Apps'] as List?) ?? const [];
    return ConfigRoot(
      network: network,
      apps: appsJson
          .whereType<Map>()
          .map((e) => AppTunnel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      logLevel: (json['LogLevel'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'Network': network.toJson(),
        'Apps': apps.map((e) => e.toJson()).toList(),
        'LogLevel': logLevel,
      };

  ConfigRoot copyWith({
    NetworkConfig? network,
    List<AppTunnel>? apps,
    int? logLevel,
  }) {
    return ConfigRoot(
      network: network ?? this.network,
      apps: apps ?? this.apps,
      logLevel: logLevel ?? this.logLevel,
    );
  }
}

class NetworkConfig {
  NetworkConfig({
    required this.token,
    required this.node,
    required this.user,
    required this.shareBandwidth,
    required this.serverHost,
    required this.serverPort,
    required this.publicIPPort,
  });

  final BigInt token;
  final String node;
  final String user;
  final int shareBandwidth;
  final String serverHost;
  final int serverPort;
  final int publicIPPort;

  static NetworkConfig defaults() {
    return NetworkConfig(
      token: BigInt.parse('11602319472897248650'),
      node: '',
      user: 'gldoffice',
      shareBandwidth: 9999,
      serverHost: 'api.openp2p.cn',
      serverPort: 27183,
      publicIPPort: 0,
    );
  }

  factory NetworkConfig.fromJson(Map<String, dynamic> json) {
    final d = NetworkConfig.defaults();
    final tokenValue = json['Token'];
    BigInt tokenBigInt;
    if (tokenValue is int) {
      tokenBigInt = BigInt.from(tokenValue);
    } else if (tokenValue is num) {
      tokenBigInt = BigInt.from(tokenValue.toInt());
    } else if (tokenValue is String) {
      try {
        tokenBigInt = BigInt.parse(tokenValue);
      } catch (_) {
        tokenBigInt = d.token;
      }
    } else {
      tokenBigInt = d.token;
    }
    
    return NetworkConfig(
      token: tokenBigInt,
      node: (json['Node'] as String?) ?? d.node,
      user: (json['User'] as String?) ?? d.user,
      shareBandwidth: (json['ShareBandwidth'] as num?)?.toInt() ?? d.shareBandwidth,
      serverHost: (json['ServerHost'] as String?) ?? d.serverHost,
      serverPort: (json['ServerPort'] as num?)?.toInt() ?? d.serverPort,
      publicIPPort: (json['PublicIPPort'] as num?)?.toInt() ?? d.publicIPPort,
    );
  }

  Map<String, dynamic> toJson() {
    // Use custom JSON encoding to preserve large token value
    // Write token as raw number string that JSON encoder will handle
    return {
      'Token': token.toString(),
      'Node': node,
      'User': user,
      'ShareBandwidth': shareBandwidth,
      'ServerHost': serverHost,
      'ServerPort': serverPort,
      'PublicIPPort': publicIPPort,
    };
  }

  NetworkConfig copyWith({
    BigInt? token,
    String? node,
    String? user,
    int? shareBandwidth,
    String? serverHost,
    int? serverPort,
    int? publicIPPort,
  }) {
    return NetworkConfig(
      token: token ?? this.token,
      node: node ?? this.node,
      user: user ?? this.user,
      shareBandwidth: shareBandwidth ?? this.shareBandwidth,
      serverHost: serverHost ?? this.serverHost,
      serverPort: serverPort ?? this.serverPort,
      publicIPPort: publicIPPort ?? this.publicIPPort,
    );
  }
}

class AppTunnel {
  AppTunnel({
    required this.appName,
    required this.protocol,
    required this.underlayProtocol,
    required this.punchPriority,
    required this.whitelist,
    required this.srcPort,
    required this.peerNode,
    required this.dstPort,
    required this.dstHost,
    required this.peerUser,
    required this.relayNode,
    required this.forceRelay,
    required this.enabled,
  });

  final String appName;
  final String protocol;
  final String underlayProtocol;
  final int punchPriority;
  final String whitelist;
  final int srcPort;
  final String peerNode;
  final int dstPort;
  final String dstHost;
  final String peerUser;
  final String relayNode;
  final int forceRelay;
  final int enabled;

  factory AppTunnel.fromJson(Map<String, dynamic> json) {
    return AppTunnel(
      appName: (json['AppName'] as String?) ?? '',
      protocol: (json['Protocol'] as String?) ?? 'tcp',
      underlayProtocol: (json['UnderlayProtocol'] as String?) ?? '',
      punchPriority: (json['PunchPriority'] as num?)?.toInt() ?? 0,
      whitelist: (json['Whitelist'] as String?) ?? '',
      srcPort: (json['SrcPort'] as num?)?.toInt() ?? 0,
      peerNode: (json['PeerNode'] as String?) ?? '',
      dstPort: (json['DstPort'] as num?)?.toInt() ?? 0,
      dstHost: (json['DstHost'] as String?) ?? 'localhost',
      peerUser: (json['PeerUser'] as String?) ?? '',
      relayNode: (json['RelayNode'] as String?) ?? '',
      forceRelay: (json['ForceRelay'] as num?)?.toInt() ?? 0,
      enabled: (json['Enabled'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'AppName': appName,
        'Protocol': protocol,
        'UnderlayProtocol': underlayProtocol,
        'PunchPriority': punchPriority,
        'Whitelist': whitelist,
        'SrcPort': srcPort,
        'PeerNode': peerNode,
        'DstPort': dstPort,
        'DstHost': dstHost,
        'PeerUser': peerUser,
        'RelayNode': relayNode,
        'ForceRelay': forceRelay,
        'Enabled': enabled,
      };

  AppTunnel copyWith({
    String? appName,
    String? protocol,
    String? underlayProtocol,
    int? punchPriority,
    String? whitelist,
    int? srcPort,
    String? peerNode,
    int? dstPort,
    String? dstHost,
    String? peerUser,
    String? relayNode,
    int? forceRelay,
    int? enabled,
  }) {
    return AppTunnel(
      appName: appName ?? this.appName,
      protocol: protocol ?? this.protocol,
      underlayProtocol: underlayProtocol ?? this.underlayProtocol,
      punchPriority: punchPriority ?? this.punchPriority,
      whitelist: whitelist ?? this.whitelist,
      srcPort: srcPort ?? this.srcPort,
      peerNode: peerNode ?? this.peerNode,
      dstPort: dstPort ?? this.dstPort,
      dstHost: dstHost ?? this.dstHost,
      peerUser: peerUser ?? this.peerUser,
      relayNode: relayNode ?? this.relayNode,
      forceRelay: forceRelay ?? this.forceRelay,
      enabled: enabled ?? this.enabled,
    );
  }

  String get localLoopback => '127.0.0.1:$srcPort';
}

