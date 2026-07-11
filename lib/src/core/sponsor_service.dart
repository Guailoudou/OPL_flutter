import 'dart:convert';
import 'package:http/http.dart' as http;

import 'url_config.dart';
import 'sponsor_models.dart';

class SponsorService {
  Future<SponsorResponse?> fetchSponsors() async {
    try {
      final resp = await http.get(Uri.parse(UrlConfig.sponsorsApiUrl));
      if (resp.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return SponsorResponse.fromJson(decoded);
    } catch (e) {
      return null;
    }
  }
}
