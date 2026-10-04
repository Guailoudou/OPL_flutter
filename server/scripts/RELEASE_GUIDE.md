# 自动化版本发布指南

## 概述

本脚本用于自动化发布 App、Core、EasyTier 三个组件的版本更新。

## 前置准备

### 1. 安装依赖

```bash
cd server
npm install ssh2-sftp-client
```

### 2. 配置环境变量

复制配置模板并填写 SFTP 连接信息：

```bash
cp server/scripts/.env.example server/scripts/.env
```

编辑 `.env` 文件：

```env
SFTP_HOST=your-server.com
SFTP_PORT=22
SFTP_USER=your-username
SFTP_KEY=/path/to/your/private/key  # 或 SFTP_PASS=your-password
SFTP_REMOTE=/file/releases
RELEASES_URL=https://file.gldhn.top/file/releases
```

## 发布流程

### App 发布（自动构建）

App 会自动构建当前平台的 Flutter 应用：

```bash
node server/scripts/release.js app 0.2.0 "新增XX功能\n修复XX问题"
```

**脚本自动执行：**
1. 更新 `pubspec.yaml` 版本号和 buildNumber
2. 运行 `flutter build windows --release`（Windows）
3. 复制构建产物到 staging 目录
4. 计算 SHA256
5. 通过 SFTP 上传到服务器
6. 更新 `releases.json`

### Android App 发布

```bash
node server/scripts/release.js android 0.2.0 "新增XX功能\n修复XX问题"
```

脚本会构建 `app-release.apk`、计算 SHA256、上传 APK，并更新
`releases.json` 中的 `app.url.android` 与 `app.hash.android`。

### Core 发布（手动放置产物）

Core 需要从 OpenP2P 官方获取构建产物：

**步骤 1：下载构建产物**

从 OpenP2P 官方下载三个平台的 tar.gz 文件，放到 `server/scripts/.staging/` 目录：

```
server/scripts/.staging/
├── openp2p-windows-amd64.tar.gz
├── openp2p-linux-amd64.tar.gz
└── openp2p-macos-amd64.tar.gz
```

**步骤 2：运行发布脚本**

```bash
node server/scripts/release.js core 1.3.0
```

**脚本自动执行：**
1. 读取 staging 目录中的三个平台文件
2. 计算每个文件的 SHA256
3. 通过 SFTP 上传到服务器
4. 更新 `releases.json` 中 `core` 部分

### EasyTier 发布（手动放置产物）

EasyTier 需要从 GitHub Releases 下载：

**步骤 1：下载构建产物**

从 [EasyTier GitHub Releases](https://github.com/EasyTier/EasyTier/releases) 下载三个平台的 zip 文件，放到 `server/scripts/.staging/` 目录：

```
server/scripts/.staging/
├── easytier-windows-x86_64-v2.7.0.zip
├── easytier-linux-x86_64-v2.7.0.zip
└── easytier-macos-v2.7.0.zip
```

**步骤 2：运行发布脚本**

```bash
node server/scripts/release.js easytier 2.7.0
```

**脚本自动执行：**
1. 读取 staging 目录中的三个平台文件
2. 计算每个文件的 SHA256
3. 通过 SFTP 上传到服务器
4. 更新 `releases.json` 中 `easytier` 部分

### 全量发布

一次性发布所有组件：

```bash
node server/scripts/release.js all 0.2.0 "更新日志"
```

**注意：** 全量发布前需要确保 staging 目录中已放置 Core 和 EasyTier 的构建产物。

## 客户端更新流程

发布完成后，客户端通过 `UpdateService` 自动完成更新：

1. **检查更新**：请求 `<基础地址>/data/releases.json` 获取最新版本信息
2. **版本比较**：使用 `SemVer` 比较本地版本和远程版本
3. **流式下载**：下载文件并实时显示进度
4. **校验文件**：验证 SHA256（跳过 `placeholder_hash`）
5. **解压安装**：
   - **Core**：解压 tar.gz → 找到可执行文件 → 重命名到 config 目录 → chmod +x
   - **EasyTier**：解压 zip → 释放到 config 目录 → chmod +x → 调用 `--version` 获取实际版本号
   - **Android App**：下载并校验 APK → 请求未知来源安装权限 → 打开系统安装界面

## 目录结构

```
server/scripts/
├── release.js          # 发布脚本
├── .env                # SFTP 配置（不提交到 Git）
├── .env.example        # 配置模板
└── .staging/           # 构建产物临时目录（自动创建）
    ├── openp2p-windows-amd64.tar.gz
    ├── openp2p-linux-amd64.tar.gz
    ├── openp2p-macos-amd64.tar.gz
    ├── easytier-windows-x86_64-v2.7.0.zip
    ├── easytier-linux-x86_64-v2.7.0.zip
    └── easytier-macos-v2.7.0.zip
```

## 常见问题

### Q: 如何只发布单个平台的 Core/EasyTier？

脚本会跳过 staging 目录中不存在的文件，可以只放置需要的平台文件。

### Q: 未配置 SFTP 会怎样？

脚本会跳过上传步骤，只更新 `releases.json`。你需要手动上传文件到服务器。

### Q: 如何查看当前版本信息？

查看 `server/src/data/releases.json` 文件。

### Q: 发布失败如何回滚？

1. 恢复 `pubspec.yaml` 中的版本号
2. 恢复 `releases.json` 到上一个版本
3. 从服务器删除新上传的文件

## 版本命名规范

- **App**：语义化版本，如 `0.2.0`
- **Core**：与 OpenP2P 官方版本保持一致，如 `1.3.0`
- **EasyTier**：与 EasyTier 官方版本保持一致，如 `2.7.0`

## 安全注意事项

1. **不要提交 `.env` 文件**：包含 SFTP 密码等敏感信息
2. **使用 SSH 私钥**：比密码更安全
3. **验证文件完整性**：脚本会自动计算 SHA256，客户端会校验
4. **备份 releases.json**：发布前建议备份
