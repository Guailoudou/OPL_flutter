# OPL Config Manager

Flutter 跨平台 OpenP2P 配置管理器。默认后端地址暂保留为 `http://192.168.3.194:3000`。

| 平台 | 功能与构建范围 |
| --- | --- |
| Windows x64 | 界面、配置、OpenP2P 核心；发行包包含 Wintun |
| Linux x64 / arm64 | 界面、配置、OpenP2P 核心 |
| macOS x64 / arm64 | 界面、配置、核心打包；独立核心/VPN 的沙箱策略尚待确认 |
| Android | 界面、配置、前台服务、VPN 授权与 TUN 桥接 |
| 鸿蒙 arm64 | 界面、配置、与参考工程相同的 OpenP2P 动态库、VPN Extension 与保活 |
| iOS | 界面与配置，不启动核心 |
| Web | 界面与浏览器本地配置，不启动核心 |

## 开发与验证

桌面、Android、iOS、Web 使用标准 Flutter；当前验证版本为 Flutter 3.41.4 / Dart 3.11.1。鸿蒙使用独立 OHOS Flutter 3.27.4 / Dart 3.6.2。不要让两套 SDK 共用生成的依赖目录。

```sh
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub --platform chrome test/config_browser_test.dart
flutter build web --release
```

Windows Flutter SDK 的 CanvasKit 测试服务器存在路径分隔符兼容问题；浏览器测试优先在 Linux CI 执行。Web 配置存储在 localStorage，原生配置保存到应用数据目录。损坏的配置会报告错误并保留原文件，不会被默认值覆盖。

| 目录 | 用途 |
| --- | --- |
| lib / test | Flutter 业务与回归测试 |
| third_party/openp2p | 随仓库提供的桌面核心源码、许可证与来源校验信息 |
| android | Android Service、VPN 与 JNI 接口 |
| ohos | 当前鸿蒙工程；opl_ohos 为历史工程 |
| server / server/admin | 后端 API 与管理界面 |
| scripts | 平台构建与打包脚本 |

## 桌面发行包与 GitHub Actions

在目标平台安装 Flutter、Python 3.11+ 和 Go 1.20.x。Windows 还需要 Visual Studio C++ 桌面工具；Linux 需要 GTK、Clang、CMake、Ninja 和 AppIndicator 开发包；macOS 需要 Xcode。

```sh
python scripts/build_desktop.py --arch x64
# 在 Linux / macOS arm64 主机上：
python scripts/build_desktop.py --arch arm64
```

脚本编译 Flutter 与仓库内 OpenP2P 核心，输出 `dist/opl-<platform>-<arch>.zip` 或 `.tar.gz`，同时生成 SHA-256 文件与元数据。Windows 打包脚本下载固定版本官方 Wintun，先校验归档哈希，再打包对应架构的 DLL 和许可证。桌面配置与日志写入 applicationSupport 的 OPL 子目录；核心从安装目录内的 OPL 加载，在线更新的核心保存到可写应用目录。

[`.github/workflows/desktop.yml`](.github/workflows/desktop.yml) 支持 push、PR、版本标签与 Actions 页面手动触发。流程先执行 Flutter、浏览器、Web、后端与管理界面验证，再生成 Windows x64、Linux x64/arm64、macOS x64/arm64 五种包；macOS arm64 任务同时检查 iOS 无签名构建。可在各任务的 Artifacts 下载发行包。工作流不会自动发布 Release、上传签名密钥或执行公证。

macOS 保留现有 App Sandbox；在沙箱策略确认和 macOS 实机验证完成前，不宣称其独立核心与 VPN 可用。桌面 TUN 还需要系统网络设备权限；Windows 通常需要管理员权限，Linux 需要 /dev/net/tun 与相应网络管理权限，macOS 需要系统允许创建虚拟接口。普通端口映射不自动提升整个应用权限。

## Android

```sh
flutter build apk --debug --target-platform android-arm64
flutter build apk --release --split-per-abi
```

使用 `android/app/libs/openp2p.aar`。启动前请求系统 VPN 授权；后台采用 specialUse 前台服务，由原生 TUN 桥接 SDWAN 数据包。安装 APK 更新时仍需用户允许安装未知来源应用。正式发布需配置自己的签名，目前工程的 Release 签名配置仍用于本地验证。

## 鸿蒙

见 [鸿蒙构建流程](docs/OHOS_BUILD_WORKFLOW.md)。核心 SO 与头文件必须成对同步；当前与 `D:/Guail/Documents/openp2p-master/ohos` 参考工程一致。构建脚本使用独立暂存目录并通过 `devecocli` 构建，不改变标准 Flutter 的依赖状态。

## 后端与管理界面

```sh
cd server
npm ci
npm test
npm run build
# 设置 ADMIN_TOKEN、PORT、OPL_DATA_DIR 后：
npm start
```

环境变量示例见 [server/.env.example](server/.env.example)。公开 GET 接口保留；写接口要求 `X-Admin-Token`，未配置管理令牌时返回 503，令牌错误返回 401。管理界面令牌只保存在当前浏览器会话中。

```sh
cd server/admin
npm ci
npm run build
```

版本数据可按 `windows-x64`、`linux-x64`、`linux-arm64`、`macos-x64`、`macos-arm64` 指定下载，兼容原有平台键。在线更新要求 HTTPS 与 SHA-256，限制下载/解压大小，并检查目录穿越；日志导出会隐藏 Token。

## 当前验证边界

本机已验证 Windows、Android、Web 与鸿蒙构建，以及 Linux/macOS 核心交叉编译。完整 Linux/macOS Flutter 包和 iOS 构建由 GitHub Actions 验证，尚未执行远程流程。Android/鸿蒙 VPN 转发、断网恢复、锁屏和长时间后台保活仍需真机测试；构建成功不代表这些设备行为已经验证。
