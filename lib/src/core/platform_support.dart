import 'dart:io';
import 'package:flutter/foundation.dart';

/// Platform checks shared by the Flutter and OpenHarmony targets.
///
/// OpenHarmony Flutter reports `ohos` from dart:io. Keeping this check in one
/// place prevents the OHOS build from accidentally taking desktop or the
/// unimplemented generic-mobile path.
class PlatformSupport {
  PlatformSupport._();

  static bool get isWeb => kIsWeb;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isOhos => !kIsWeb && Platform.operatingSystem == 'ohos';
  static bool get isDesktop => isWindows || isLinux || isMacOS;
  static bool get isAndroidLike => isAndroid || isOhos;
  static bool get isMobile => isAndroidLike || isIOS;
  static bool get canRunCore => isDesktop || isAndroidLike;
  static bool get canRunEasyTier => isDesktop;
}
