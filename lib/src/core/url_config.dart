class UrlConfig {
  UrlConfig._();

  // 静态 JSON 文件所在站点的基础 URL。
  // 部署时只需把 server/src/data 目录映射到该站点的 /data 路径。
  static const String defaultApiBase = 'http://192.168.3.194:3000';
  static String _apiBase = defaultApiBase;

  static void setApiBase(String value) {
    _apiBase = value.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  static String get apiBase => _apiBase;

  static String get dataBaseUrl => '$_apiBase/data';
  static String get presetJsonUrl => '$dataBaseUrl/preset.json';
  static String get noticesJsonUrl => '$dataBaseUrl/notices.json';
  static String get sponsorsJsonUrl => '$dataBaseUrl/sponsors.json';
  static String get releasesJsonUrl => '$dataBaseUrl/releases.json';

  // 基础 URL 配置（用于文件下载）
  static const String _baseUrl = 'https://file.gldhn.top/';
  static const String _giteeBaseUrl =
      'https://gitee.com/guailoudou/urlfile/raw/main/';

  // 核心文件基础 URL
  static String get filesBaseUrl {
    return '${_useGitee ? _giteeBaseUrl : _baseUrl}file/openp2p_releases';
  }

  // 是否使用 Gitee 镜像
  static bool _useGitee = false;

  static void setUseGitee(bool value) {
    _useGitee = value;
  }

  static bool get useGitee => _useGitee;
}
