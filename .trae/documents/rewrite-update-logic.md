# 重写软件更新逻辑

## Context

当前软件更新逻辑分散在多个文件中，存在以下问题：
- **App 更新**：仅打开浏览器 URL 下载，无应用内下载/安装
- **Core 下载**：hash 校验对 placeholder_hash 跳过，逻辑散落在 CoreRunner 中
- **EasyTier 下载**：无进度反馈，逻辑散落在 EasyTierService 中
- **版本比较**：使用简单字符串比较，非语义化版本比较
- **UI 不一致**：核心显示"检查更新"，EasyTier 显示"安装"/"检查更新"，体验不统一

目标：创建统一的 `UpdateService`，提供应用内下载+进度+安装能力。

## 新建文件

### 1. `lib/src/models/semver.dart`
语义化版本解析和比较：
- `SemVer.parse(String)` 解析 "1.2.3" 格式
- `compareTo(SemVer)` 比较版本大小
- 处理 "v" 前缀

### 2. `lib/src/models/release_info.dart`
Releases API 响应数据模型：
- `ReleaseInfo` - 顶层结构，包含 app/core/easytier
- `PlatformRelease` - 单平台版本信息（version, url, hash, filename）
- `AppReleaseInfo` - App 版本信息（含多平台 URL）
- `forCurrentPlatform()` 方法获取当前平台信息

### 3. `lib/src/services/update_service.dart`
核心更新服务（ChangeNotifier）：

```dart
enum UpdateComponent { app, core, easytier }
enum UpdateState { idle, checking, updateAvailable, downloading, extracting, upToDate, error }

class UpdateService extends ChangeNotifier {
  // 状态管理
  Map<UpdateComponent, UpdateState> _states = {};
  Map<UpdateComponent, double> _progress = {};
  ReleaseInfo? _cachedRelease;

  // 公共 API
  Future<void> checkAllUpdates();                              // 启动时调用
  Future<void> downloadAndInstall(UpdateComponent, {onProgress}); // 下载+安装
  String? getInstalledVersion(UpdateComponent);                 // 获取已安装版本
  String? getLatestVersion(UpdateComponent);                    // 获取最新版本
  UpdateState getState(UpdateComponent);                        // 获取当前状态
  double getProgress(UpdateComponent);                          // 获取下载进度

  // 内部方法
  Future<ReleaseInfo> _fetchReleaseInfo();
  Future<List<int>> _downloadWithProgress(url, onProgress);    // 流式下载
  bool _verifyHash(bytes, expectedHash);                        // SHA256 校验
  Future<void> _extractCore(bytes, version);                    // tar.gz 解压
  Future<void> _extractEasyTier(bytes, version);                // zip 解压
  Future<void> _installApp(bytes, version);                     // 应用安装
}
```

关键实现细节：
- **流式下载**：使用 `http.Client().send()` + `StreamedResponse`，逐块读取并报告进度
- **Hash 校验**：跳过 `placeholder_hash`，其余正常校验
- **Core 解压**：GZipDecoder → TarDecoder → 找可执行文件 → 重命名到 coreFile 路径 → chmod +x
- **EasyTier 解压**：ZipDecoder → 解压到 config 目录 → chmod +x → 调用 --version 获取版本
- **App 安装**：Windows 保存 exe 到临时目录并启动安装；macOS 打开 dmg；Linux 提取替换

### 4. `lib/src/widgets/update_progress_dialog.dart`
可复用下载进度对话框：
- 标题 + LinearProgressIndicator + 百分比文字
- 下载中显示进度，完成后自动关闭
- 失败显示错误信息和重试按钮

### 5. `lib/src/widgets/update_tile.dart`
可复用设置页组件：
- icon + title + 当前版本 subtitle + 右侧操作按钮
- 根据 UpdateState 显示不同按钮文字：
  - 未安装 → "安装"
  - 已是最新 → "已是最新"（绿色文字）
  - 有更新 → "更新到 vX.Y.Z"
  - 检查中 → CircularProgressIndicator
  - 下载中 → 显示进度百分比

## 修改文件

### `lib/src/state/app_controller.dart`
- **删除**：`_checkAppUpdate()`, `_showUpdateDialog()`, `checkCoreVersionStatus()`, `checkEasyTierVersionStatus()`
- **添加**：`late final UpdateService updateService` 字段
- **init() 中**：创建 UpdateService，调用 `detectInstalledVersions()` 和 `checkAllUpdates()`
- 保留 `_updateCoreVersion` 和 `_updateEasyTierVersion` 回调

### `lib/src/state/core_runner.dart`
- **删除**：`fetchLatestRelease()`, `ensureCorePresent()`, `CoreRelease` 类
- **保留**：`start()`, `stop()`, 进程管理逻辑
- `start()` 中核心不存在时抛出明确错误提示

### `lib/src/core/easytier_service.dart`
- **删除**：`downloadEasyTier()` 方法
- **保留**：所有进程/网络管理逻辑
- `createNetwork()` 和 `joinNetwork()` 中未安装时抛出错误提示用户去设置页安装

### `lib/src/ui/pages/settings_page.dart`
- 替换 L163-316 的核心和 EasyTier ListTile 为三个 `UpdateTile`：
  - 应用版本（UpdateComponent.app）
  - 核心版本（UpdateComponent.core）
  - EasyTier 组网核心（UpdateComponent.easytier）

### `lib/src/core/url_config.dart`
- 删除 `easyTierDownloadUrl` getter（不再需要硬编码 URL）

## 实施顺序

1. 创建 `semver.dart` - 版本比较基础
2. 创建 `release_info.dart` - 数据模型
3. 创建 `update_service.dart` - 核心服务
4. 创建 `update_progress_dialog.dart` - 进度对话框
5. 创建 `update_tile.dart` - 设置页组件
6. 修改 `app_controller.dart` - 集成 UpdateService
7. 修改 `core_runner.dart` - 移除下载逻辑
8. 修改 `easytier_service.dart` - 移除下载逻辑
9. 修改 `settings_page.dart` - 使用 UpdateTile
10. 修改 `url_config.dart` - 清理无用代码
11. 构建测试

## 验证方式

1. 启动应用，观察设置页三个组件的版本显示是否正确
2. 点击"检查更新"，验证版本比较逻辑
3. 点击"安装"/"更新"，验证下载进度条显示
4. 下载完成后验证文件正确解压到目标路径
5. 验证 EasyTier 版本号自动检测并显示
6. 验证网络异常时的错误提示和重试功能
