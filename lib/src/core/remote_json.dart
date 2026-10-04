import 'dart:convert';

import 'package:http/http.dart' as http;

const Duration remoteJsonTimeout = Duration(seconds: 5);

/// Reads one JSON object from the static data directory.
Future<Map<String, dynamic>> fetchJsonDocument(String url) async {
  final client = http.Client();
  try {
    final response =
        await client.get(Uri.parse(url)).timeout(remoteJsonTimeout);
    if (response.statusCode != 200) {
      throw StateError('Failed to fetch $url: HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The JSON root must be an object');
    }
    return decoded;
  } finally {
    client.close();
  }
}
