import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/url_config.dart';
import 'preset_models.dart';

class PresetService {
  final String baseUrl;

  PresetService({String? baseUrl}) : baseUrl = baseUrl ?? UrlConfig.apiBaseUrl;

  /// 获取预设隧道列表
  Future<List<PresetTunnel>> getPresets() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/presets'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final presetsJson = data['presets'] as List;
        return presetsJson.map((json) => PresetTunnel.fromJson(json)).toList();
      } else {
        throw Exception('获取预设失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取预设失败: $e');
    }
  }

  /// 根据 ID 获取预设
  Future<PresetTunnel?> getPresetById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/presets/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return PresetTunnel.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('获取预设失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取预设失败: $e');
    }
  }
}
