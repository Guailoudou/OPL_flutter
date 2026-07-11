# OPL 后端服务 + 缺失功能补齐 实施计划

## Context

当前 OPL (OpenP2P Launcher) Flutter 客户端已实现隧道管理、进程管理、公告、UID 等核心功能，但存在以下问题：
1. 所有远程数据（公告、预设、赞助列表、版本信息）依赖静态 JSON 文件托管（file.gldhn.top / Gitee），无法动态管理
2. 缺少预设隧道、赞助列表、连接码解析/导出、主程序自更新等功能
3. 需要统一后端服务来支撑多端（Windows/Linux/macOS/Android/iOS）客户端

目标：用 Node.js 实现后端服务，并补齐 Flutter 客户端缺失功能。

---

## 第一部分：Node.js 后端服务

### 目录结构

```
d:\Guail\Documents\flutter\server\
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts              # 入口，Express 启动
│   ├── config.ts             # 配置（端口、数据路径）
│   ├── db.ts                 # JSON 文件存储层（轻量，无需数据库）
│   ├── routes/
│   │   ├── preset.ts         # 预设隧道 API
│   │   ├── notice.ts         # 公告 API
│   │   ├── sponsor.ts        # 赞助列表 API
│   │   ├── release.ts        # 版本更新 API（核心 + 主程序）
│   │   └── health.ts         # 健康检查
│   └── data/                 # JSON 数据文件（运行时生成）
│       ├── preset.json
│       ├── notices.json
│       ├── sponsors.json
│       └── releases.json
```

### 技术选型

- **运行时**: Node.js 18+
- **框架**: Express 4
- **语言**: TypeScript
- **存储**: JSON 文件（与现有客户端数据格式一致，轻量无依赖）
- **CORS**: 允许所有来源（客户端跨平台调用）

### API 设计

#### 1. 预设隧道 `GET /api/preset`

返回格式（兼容设计文档 Presets 模型）：

```json
{
  "version": 3,
  "presets": [
    {
      "id": "minecraft",
      "name": "Minecraft 联机",
      "protocol": "tcp",
      "dstPort": 25565,
      "description": "Minecraft Java 版默认端口"
    }
  ],
  "servers": [
    { "name": "主节点", "host": "api.openp2p.cn", "port": 27183 }
  ],
  "uplog": "1.0.2 修复了xxx",
  "upurl": "https://file.gldhn.top/file/openp2p_releases/nvb.zip",
  "uphash": "sha256hash",
  "opurl": "https://file.gldhn.top/file/openp2p_releases/openp2p.zip",
  "ophash": "sha256hash"
}
```

#### 2. 公告 `GET /api/notices`

```json
{
  "notices": [
    { "title": "v1.0 发布", "content": "...", "time": "2026-07-11 12:00:00" }
  ]
}
```

#### 3. 赞助列表 `GET /api/sponsors`

```json
{
  "sponsors": [
    { "name": "用户A", "amount": 50, "time": "2026-07-01", "message": "加油！" }
  ]
}
```

#### 4. 版本更新 `GET /api/releases`

```json
{
  "app": {
    "version": "0.1.1",
    "buildNumber": 2,
    "changelog": "新增预设隧道功能",
    "url": "https://file.gldhn.top/file/releases/opl-0.1.1.exe",
    "hash": "sha256..."
  },
  "core": [
    {
      "platform": "windows",
      "architecture": "amd64",
      "version": "1.2.3",
      "filename": "openp2p-windows-amd64.tar.gz",
      "sha256": "..."
    }
  ]
}
```

### 启动脚本

```json
{
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js"
  }
}
```

默认端口 `3000`，可通过环境变量 `PORT` 覆盖。

---

## 第二部分：Flutter 客户端补齐功能

### 2.1 更新 URL 配置指向后端

**文件**: `lib/src/core/url_config.dart`

- 添加 `apiBase` 配置项（默认 `http://localhost:3000`，可配置）
- 将 `noticeBaseUrl`、`releasesUrl` 等改为调用后端 API
- 保留 Gitee 镜像 fallback 逻辑

### 2.2 预设隧道功能

**新增文件**:
- `lib/src/core/preset_models.dart` — 预设数据模型
- `lib/src/core/preset_service.dart` — 从后端获取预设

**修改文件**:
- `lib/src/ui/pages/tunnels_page.dart` — FAB 区域添加"预设"按钮
- 新增 `lib/src/ui/pages/preset_page.dart` — 预设列表页面，点击可快速添加隧道

**逻辑**:
1. 启动时从 `GET /api/preset` 获取预设列表，缓存到本地
2. 用户点击预设 → 弹出编辑对话框（预填端口等参数）→ 确认后添加到隧道列表
3. 预设数据模型包含 `id/name/protocol/dstPort/description`

### 2.3 赞助列表

**新增文件**:
- `lib/src/core/sponsor_service.dart` — 从后端获取赞助列表

**修改文件**:
- `lib/src/ui/pages/me_page.dart` — 在"关于"卡片下方添加"赞助名单"卡片

**逻辑**:
1. 从 `GET /api/sponsors` 获取赞助者列表
2. 展示用户名、金额、留言、时间
3. 感谢语 + 赞助引导

### 2.4 连接码解析与导出

**新增文件**:
- `lib/src/core/connection_code.dart` — 连接码解析/生成工具

**修改文件**:
- `lib/src/ui/pages/tunnels_page.dart` — FAB 添加"快速添加"选项（解析连接码）
- 隧道操作菜单添加"导出连接码"

**连接码格式**（兼容设计文档）:
- 标准: `协议:UID:远程端口:本地端口`（协议 1=tcp, 2=udp）
- 简化: `UID:远程端口`（默认 TCP，本地=远程）
- 多连接: 用 `;` 分隔

### 2.5 主程序自更新检测

**修改文件**:
- `lib/src/state/app_controller.dart` — 启动时检查 `GET /api/releases` 中的 `app` 字段
- `lib/src/ui/pages/settings_page.dart` — 显示主程序版本状态

**逻辑**:
1. 对比 `package_info_plus` 获取的本地版本与服务器版本
2. 有新版本时弹窗提示（可跳过）
3. 桌面端：下载更新包并提示用户安装
4. 移动端：跳转到下载链接

### 2.6 多端适配考虑

| 功能 | Windows | Linux | macOS | Android | iOS |
|------|---------|-------|-------|---------|-----|
| 隧道管理 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 核心进程启动 | ✅ | ✅ | ✅ | ✅ (JNI) | ❌ |
| 系统托盘 | ✅ | ✅ | ✅ | ❌ | ❌ |
| 连接码解析 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 预设隧道 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 赞助列表 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 公告 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 主程序更新 | ✅ (exe) | ✅ (deb) | ✅ (dmg) | 应用商店 | 应用商店 |

---

## 实施顺序

### Phase 1: Node.js 后端（优先级最高）
1. 初始化 `server/` 目录，配置 TypeScript + Express
2. 实现 JSON 文件存储层
3. 实现 4 个 API 路由（preset/notice/sponsor/release）
4. 添加种子数据（示例预设、公告、赞助者）
5. 测试所有 API

### Phase 2: 客户端基础设施
6. 更新 `url_config.dart` 支持后端 API 地址配置
7. 添加 API 客户端封装（带错误处理和镜像切换）

### Phase 3: 补齐功能
8. 实现连接码解析/生成工具 + 快速添加 UI
9. 实现预设隧道页面
10. 实现赞助列表展示
11. 实现主程序更新检测
12. 隧道导出连接码功能

### Phase 4: 验证
13. 启动后端服务，验证所有 API 响应
14. Flutter 客户端连接后端，验证各功能
15. 多平台编译测试（至少 Windows + Android）

---

## 关键文件清单

### 新增文件
- `server/package.json`
- `server/tsconfig.json`
- `server/src/index.ts`
- `server/src/config.ts`
- `server/src/db.ts`
- `server/src/routes/preset.ts`
- `server/src/routes/notice.ts`
- `server/src/routes/sponsor.ts`
- `server/src/routes/release.ts`
- `server/src/routes/health.ts`
- `lib/src/core/preset_models.dart`
- `lib/src/core/preset_service.dart`
- `lib/src/core/sponsor_service.dart`
- `lib/src/core/connection_code.dart`
- `lib/src/ui/pages/preset_page.dart`

### 修改文件
- `lib/src/core/url_config.dart` — 添加 API base 配置
- `lib/src/core/settings_models.dart` — 添加 `apiBase` 字段
- `lib/src/state/app_controller.dart` — 预加载预设、检查主程序更新
- `lib/src/ui/pages/tunnels_page.dart` — 快速添加、导出连接码
- `lib/src/ui/pages/me_page.dart` — 赞助列表
- `lib/src/ui/pages/settings_page.dart` — API 地址配置、主程序版本

---

## 验证方式

1. **后端验证**: `cd server && npm run dev`，用浏览器/curl 访问 `http://localhost:3000/api/*` 验证 JSON 响应
2. **客户端验证**: Flutter 运行 `flutter run -d windows`，检查：
   - 公告正常加载（从后端）
   - 预设列表可显示并添加
   - 快速添加连接码 `1:abcdef0123456789:25565:25565` 正常解析
   - 赞助列表正常显示
   - 主程序版本检查正常
3. **多端验证**: `flutter run -d android` 验证移动端功能正常（无系统托盘、无核心启动但其他功能正常）
