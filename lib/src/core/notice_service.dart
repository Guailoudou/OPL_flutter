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

  bool hasNewNotice(String? lastTime, List<Notice> notices) {
    if (lastTime == null || lastTime.isEmpty) return true;
    if (notices.isEmpty) return false;

    // Sort notices by time (newest first) to get the latest one
    final sortedNotices = List<Notice>.from(notices)..sort((a, b) {
      try {
        final timeA = _parseTime(a.time);
        final timeB = _parseTime(b.time);
        return timeB.compareTo(timeA); // Descending order
      } catch (_) {
        return b.time.compareTo(a.time);
      }
    });

    final latestNoticeTime = sortedNotices.first.time;
    return _compareTime(latestNoticeTime, lastTime) > 0;
  }

  int _compareTime(String time1, String time2) {
    try {
      final date1 = _parseTime(time1);
      final date2 = _parseTime(time2);
      return date1.compareTo(date2);
    } catch (e) {
      return time1.compareTo(time2);
    }
  }

  DateTime _parseTime(String time) {
    final formats = [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-M-d HH:mm:ss',
      'yyyy-MM-dd',
      'yyyy-M-d',
    ];

    for (final format in formats) {
      try {
        return DateTime.parse(time.replaceAll(' ', 'T'));
      } catch (_) {
        continue;
      }
    }

    return DateTime.now();
  }
}
