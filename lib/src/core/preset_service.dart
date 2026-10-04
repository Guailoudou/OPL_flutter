import 'url_config.dart';
import 'preset_models.dart';
import 'remote_json.dart';

class PresetService {
  Future<PresetResponse?> fetchPresets() async {
    try {
      final decoded = await fetchJsonDocument(UrlConfig.presetJsonUrl);
      return PresetResponse.fromJson(decoded);
    } catch (e) {
      return null;
    }
  }
}
