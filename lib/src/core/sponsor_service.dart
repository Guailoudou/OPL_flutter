import 'remote_json.dart';
import 'url_config.dart';
import 'sponsor_models.dart';

class SponsorService {
  Future<SponsorResponse?> fetchSponsors() async {
    try {
      final decoded = await fetchJsonDocument(UrlConfig.sponsorsJsonUrl);
      return SponsorResponse.fromJson(decoded);
    } catch (e) {
      return null;
    }
  }
}
