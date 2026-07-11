import 'dart:io';

class UrlConfig {
  UrlConfig._();

  // 后端 API 基础 URL
  static String _apiBase = 'http://localhost:3000';

  static void setApiBase(String value) {
    _apiBase = value;
  }

  static String get apiBase => _apiBase;

  // 后端 API 端点
  static String get presetApiUrl => '$_apiBase/api/preset';
  static String get noticesApiUrl => '$_apiBase/api/notices';
  static String get sponsorsApiUrl => '$_apiBase/api/sponsors';
  static String get releasesApiUrl => '$_apiBase/api/releases';

  // EasyTier 下载 URL（多平台）
  static String get easyTierDownloadUrl {
    if (Platform.isWindows) {
      return 'https://cdn.gh-proxy.org/https://github.com/EasyTier/EasyTier/releases/download/v2.6.4/easytier-windows-x86_64-v2.6.4.zip';
    } else if (Platform.isLinux) {
      return 'https://cdn.gh-proxy.org/https://github.com/EasyTier/EasyTier/releases/download/v2.6.4/easytier-linux-x86_64-v2.6.4.zip';
    } else if (Platform.isMacOS) {
      return 'https://cdn.gh-proxy.org/https://github.com/EasyTier/EasyTier/releases/download/v2.6.4/easytier-macos-v2.6.4.zip';
    }
    throw UnsupportedError('Unsupported platform for EasyTier');
  }

  // 基础 URL 配置（用于文件下载）
  static const String _baseUrl = 'https://file.gldhn.top/';
  static const String _giteeBaseUrl = 'https://gitee.com/guailoudou/urlfile/raw/main/';

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
