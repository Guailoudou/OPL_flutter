import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/logger.dart';

class IspInfo {
  final String ip;
  final String isp;
  final String? region;
  final String? city;

  IspInfo({
    required this.ip,
    required this.isp,
    this.region,
    this.city,
  });

  factory IspInfo.fromJson(Map<String, dynamic> json) {
    return IspInfo(
      ip: json['ip'] as String? ?? '',
      isp: json['isp'] as String? ?? '',
      region: json['region'] as String?,
      city: json['city'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'isp': isp,
        'region': region,
        'city': city,
      };
}

class IspWarningService {
  static const String _apiUrl =
      'https://cn.apihz.cn/api/ip/chaapi.php?id=10001875&key=dddd7577f7f5ea74a29854ab11bbea0a';

  // 主流运营商列表
  static const List<String> _mainstreamIsps = [
    '电信',
    '联通',
    '移动',
    '铁通',
    '教育网',
    '鹏博士',
    '广电',
  ];

  IspInfo? _cachedIspInfo;
  DateTime? _lastCheckTime;
  static const Duration _cacheDuration = Duration(hours: 1);

  IspInfo? get cachedIspInfo => _cachedIspInfo;

  Future<IspInfo?> fetchIspInfo({bool forceRefresh = false}) async {
    // 检查缓存是否有效
    if (!forceRefresh &&
        _cachedIspInfo != null &&
        _lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!) < _cacheDuration) {
      L.d('using cached ISP info', tag: 'isp');
      return _cachedIspInfo;
    }

    try {
      L.d('fetching ISP info...', tag: 'isp');

      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        L.w('failed to fetch ISP info: HTTP ${response.statusCode}',
            tag: 'isp');
        return null;
      }

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        L.w('invalid ISP info response format', tag: 'isp');
        return null;
      }

      final code = json['code'];
      if (code != null && code != 200) {
        L.w('ISP API returned error code: $code, msg: ${json['msg']}',
            tag: 'isp');
        return null;
      }

      // API直接返回数据，字段名是中文
      final ispInfo = IspInfo(
        ip: json['ip'] as String? ?? '',
        isp: json['isp'] as String? ?? '',
        region: json['sheng'] as String?,
        city: json['shi'] as String?,
      );
      _cachedIspInfo = ispInfo;
      _lastCheckTime = DateTime.now();

      L.i('fetched ISP info: ${ispInfo.isp} (${ispInfo.ip})', tag: 'isp');
      return ispInfo;
    } catch (e) {
      L.e('failed to fetch ISP info', tag: 'isp', error: e);
      return null;
    }
  }

  bool isMainstreamIsp(String isp) {
    final ispLower = isp.toLowerCase();
    return _mainstreamIsps
        .any((mainIsp) => ispLower.contains(mainIsp.toLowerCase()));
  }

  bool shouldShowWarning(String isp) {
    return !isMainstreamIsp(isp);
  }

  String getWarningMessage(String isp) {
    return '检测到您当前运营商为：$isp\n\n'
        '该运营商可能不是主流运营商，可能会影响 P2P 连接质量。\n\n'
        '建议：\n'
        '1. 使用主流运营商（电信、联通、移动）以获得更好的连接体验\n'
        '2. 如果连接不稳定，可以尝试切换到其他网络\n'
        '3. 部分小众运营商可能存在 NAT 限制，影响打洞成功率';
  }

  void dispose() {
    _cachedIspInfo = null;
    _lastCheckTime = null;
  }
}
