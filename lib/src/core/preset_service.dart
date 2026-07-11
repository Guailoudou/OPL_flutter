import 'dart:convert';
import 'package:http/http.dart' as http;

import 'url_config.dart';
import 'preset_models.dart';

class PresetService {
  Future<PresetResponse?> fetchPresets() async {
    try {
      final resp = await http.get(Uri.parse(UrlConfig.presetApiUrl));
      if (resp.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return PresetResponse.fromJson(decoded);
    } catch (e) {
      return null;
    }
  }
}
