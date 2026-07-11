class TunnelConfig {
  TunnelConfig({
    required this.sport,
    required this.cport,
    required this.type,
  });

  final int sport;
  final int cport;
  final String type;

  factory TunnelConfig.fromJson(Map<String, dynamic> json) {
    return TunnelConfig(
      sport: json['Sport'] as int,
      cport: json['Cport'] as int,
      type: json['type'] as String,
    );
  }
}

class PresetTunnel {
  PresetTunnel({
    required this.name,
    required this.note,
    required this.tunnel,
  });

  final String name;
  final String note;
  final List<TunnelConfig> tunnel;

  factory PresetTunnel.fromJson(Map<String, dynamic> json) {
    final tunnelJson = json['tunnel'] as List? ?? [];
    return PresetTunnel(
      name: json['name'] as String,
      note: json['note'] as String? ?? '',
      tunnel: tunnelJson
          .whereType<Map>()
          .map((e) => TunnelConfig.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class PresetResponse {
  PresetResponse({
    required this.presets,
  });

  final List<PresetTunnel> presets;

  factory PresetResponse.fromJson(Map<String, dynamic> json) {
    final presetsJson = json['presets'] as List? ?? [];
    return PresetResponse(
      presets: presetsJson
          .whereType<Map>()
          .map((e) => PresetTunnel.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}
