# 修复多平台应用更新检查

## 问题描述

在 `app_controller.dart` 的 `_checkAppUpdate` 方法中，代码尝试将 `appRelease['url']` 作为 String 读取：

```dart
downloadUrl: appRelease['url'] as String? ?? '',
```

但是 `releases.json` 中 `app.url` 已改为多平台对象结构：

```json
"url": {
  "windows": "https://file.gldhn.top/file/releases/opl-0.1.1.exe",
  "linux": "https://file.gldhn.top/file/releases/opl-0.1.1.tar.gz",
  "macos": "https://file.gldhn.top/file/releases/opl-0.1.1.dmg"
}
```

这导致类型转换失败，应用更新检查无法正常工作。

## 修复方案

### 1. 修复 `app_controller.dart` 中的 URL 读取

**文件**: `d:\Guail\Documents\flutter\lib\src\state\app_controller.dart`

**修改位置**: `_checkAppUpdate` 方法（第 251-258 行）

**修改内容**:
- 将 `appRelease['url']` 作为 Map 读取
- 根据当前平台（Windows/Linux/macOS）获取对应的下载 URL
- 使用 `dart:io` 的 `Platform` 判断当前平台

**代码修改**:
```dart
// Compare versions (simple string comparison)
if (latestVersion != currentVersion) {
  L.i('new version available: $latestVersion (current: $currentVersion)', tag: 'app');
  
  // 获取当前平台的下载 URL
  final urlData = appRelease['url'];
  String downloadUrl = '';
  if (urlData is Map<String, dynamic>) {
    final platform = Platform.isWindows
        ? 'windows'
        : Platform.isLinux
            ? 'linux'
            : Platform.isMacOS
                ? 'macos'
                : null;
    if (platform != null) {
      downloadUrl = urlData[platform] as String? ?? '';
    }
  }
  
  _showUpdateDialog(
    currentVersion: currentVersion,
    latestVersion: latestVersion,
    changelog: appRelease['changelog'] as String? ?? '',
    downloadUrl: downloadUrl,
  );
}
```

## 验证步骤

1. 编译 Flutter 应用，确保无编译错误
2. 修改 `releases.json` 中的 `app.version` 为一个更高的版本号
3. 启动应用，验证是否能正确检测到更新
4. 验证更新对话框中显示的下载链接是否为当前平台的正确链接

## 影响范围

- 仅影响 Flutter 客户端的应用更新检查功能
- 不影响后端 API 和 Vue 管理后台
- 不影响核心下载和 EasyTier 下载功能（这些已经正确处理多平台）
