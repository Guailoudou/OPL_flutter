import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/platform_support.dart';

Future<bool> openExternalLink(Uri uri) async {
  if (!['https', 'http'].contains(uri.scheme) || uri.host.isEmpty) return false;
  if (PlatformSupport.isOhos) {
    return await const MethodChannel('com.example.opl_config_manager/core')
            .invokeMethod<bool>('openExternalLink', {'url': uri.toString()}) ??
        false;
  }
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
