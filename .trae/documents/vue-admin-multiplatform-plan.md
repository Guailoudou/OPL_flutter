# Vue 管理后台 + 多平台核心管理

## Context
当前后端管理页面是一个单文件 Bootstrap HTML（admin.html），功能有限且不易维护。需要：
1. 用 Vue 3 构建完整的管理后台，替代现有 admin.html
2. 后端增加多平台核心管理接口（Windows/Linux/macOS/Android/iOS）
3. 确保 Flutter 客户端和后端都支持多平台

## 阶段一：后端多平台核心管理 API

### 1. 更新 releases.json 数据结构
文件：`server/src/data/releases.json`
```json
{
  "app": {
    "version": "0.1.1",
    "buildNumber": 2,
    "changelog": "...",
    "url": { "windows": "...", "linux": "...", "macos": "..." },
    "hash": { "windows": "...", "linux": "...", "macos": "..." }
  },
  "core": {
    "windows": { "version": "1.2.3", "url": "...", "hash": "...", "filename": "..." },
    "linux": { "version": "1.2.3", "url": "...", "hash": "...", "filename": "..." },
    "macos": { "version": "1.2.3", "url": "...", "hash": "...", "filename": "..." }
  },
  "easytier": {
    "windows": { "version": "2.6.4", "url": "...", "hash": "..." },
    "linux": { "version": "2.6.4", "url": "...", "hash": "..." },
    "macos": { "version": "2.6.4", "url": "...", "hash": "..." }
  }
}
```

### 2. 新增核心管理路由
文件：`server/src/routes/core.ts`
- `GET /api/core` - 获取所有平台核心信息
- `POST /api/core` - 更新核心信息
- `GET /api/core/:platform` - 获取指定平台核心信息
- `POST /api/core/upload` - 上传核心文件（可选）

### 3. 更新 release 路由
文件：`server/src/routes/release.ts`
- 适配新的多平台数据结构
- `GET /api/releases` - 获取版本信息（保持向后兼容）
- `POST /api/releases` - 更新版本信息

## 阶段二：Vue 3 管理后台

### 1. 项目结构
```
server/admin/
├── index.html
├── package.json
├── vite.config.ts
├── tsconfig.json
├── src/
│   ├── main.ts
│   ├── App.vue
│   ├── router/
│   │   └── index.ts
│   ├── api/
│   │   └── index.ts          # API 请求封装
│   ├── views/
│   │   ├── Dashboard.vue      # 仪表盘
│   │   ├── PresetManage.vue   # 预设隧道管理
│   │   ├── NoticeManage.vue   # 公告管理
│   │   ├── SponsorManage.vue  # 赞助列表管理
│   │   ├── ReleaseManage.vue  # 版本更新管理
│   │   └── CoreManage.vue     # 核心管理（多平台）
│   └── components/
│       ├── Layout.vue         # 布局组件
│       └── PlatformBadge.vue  # 平台标识组件
```

### 2. 技术栈
- Vue 3 + TypeScript + Vite
- Element Plus（UI 组件库，CDN 引入或 npm）
- Vue Router（路由）
- Axios（HTTP 请求）
- 构建输出到 `server/public/` 目录

### 3. 功能页面
- **仪表盘**：概览统计（预设数量、公告数量、赞助总额、各平台核心版本）
- **预设隧道管理**：CRUD 操作，支持多隧道配置
- **公告管理**：CRUD 操作
- **赞助列表管理**：CRUD 操作
- **版本更新管理**：管理 app 版本 + 各平台 core 版本 + easytier 版本
- **核心管理**：独立管理各平台（Windows/Linux/macOS）的核心文件和 EasyTier

## 阶段三：Flutter 客户端适配

### 1. 更新 CoreRunner
文件：`lib/src/state/core_runner.dart`
- 适配新的 releases.json 多平台结构
- 按平台选择正确的下载 URL

### 2. 更新 EasyTierService
文件：`lib/src/core/easytier_service.dart`
- 支持 Linux/macOS 的 EasyTier 下载
- 多平台可执行文件路径处理

### 3. 更新 URL 配置
文件：`lib/src/core/url_config.dart`
- 添加多平台核心下载 URL 辅助方法

## 阶段四：构建与集成

### 1. 构建 Vue 管理后台
- `cd server/admin && npm run build`
- 输出到 `server/public/`
- 删除旧的 `admin.html`

### 2. 更新服务器入口
文件：`server/src/index.ts`
- 静态文件服务指向 `server/public/`
- `/admin` 路由指向 Vue SPA

## 验证步骤
1. 启动后端服务 `cd server && npm run dev`
2. 访问 `http://localhost:3000/admin` 验证管理后台
3. 测试各 API 端点的 CRUD 操作
4. 编译 Flutter 客户端验证多平台核心下载
5. 验证 releases.json 数据格式兼容性
