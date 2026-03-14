import 'dart:convert';
import 'package:http/http.dart' as http;

class Notice {
  Notice({
    required this.title,
    required this.content,
    required this.time,
  });

  final String title;
  final String content;
  final String time;

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      time: json['time'] as String? ?? '',
    );
  }
}

class NoticeResponse {
  NoticeResponse({required this.notices});

  final List<Notice> notices;

  factory NoticeResponse.fromJson(Map<String, dynamic> json) {
    final noticesJson = json['notices'] as List? ?? [];
    return NoticeResponse(
      notices: noticesJson
          .whereType<Map>()
          .map((e) => Notice.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class NoticeService {
  static const String _noticeUrl =
      'https://file.gldhn.top/file/json/notice.json';

  Future<NoticeResponse?> fetchNotices() async {
    try {
      final resp = await http.get(Uri.parse(_noticeUrl));
      if (resp.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return NoticeResponse.fromJson(decoded);
    } catch (e) {
      return null;
    }
  }
}
