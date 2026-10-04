# 使用 GitHub Pages 配置 JSON 路径

本文档针对当前仓库：

```text
GitHub 用户：Guailoudou
仓库名称：OPL_flutter
默认分支：main
```

目标是通过 GitHub Pages 免费托管公告、预设、赞助名单和更新信息。客户端只读取静态 JSON，不需要长期运行 Node 服务，也不需要购买云服务器或数据库。

GitHub Pages 是静态网站托管服务。项目站点的默认地址格式是：

```text
https://<用户名>.github.io/<仓库名>/
```

因此本项目启用 Pages 后的基础地址应为：

```text
https://guailoudou.github.io/OPL_flutter
```

GitHub 官方说明：

- [GitHub Pages 简介与项目站点 URL](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages)
- [使用自定义 GitHub Actions 工作流部署 Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
- [GitHub Pages 使用限制](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits)

## 1. 最终访问地址

客户端固定读取 `server/src/data` 中的四个文件：

| 功能 | 仓库源文件 | GitHub Pages 地址 |
| --- | --- | --- |
| 预设隧道 | `server/src/data/preset.json` | `https://guailoudou.github.io/OPL_flutter/data/preset.json` |
| 公告 | `server/src/data/notices.json` | `https://guailoudou.github.io/OPL_flutter/data/notices.json` |
| 赞助名单 | `server/src/data/sponsors.json` | `https://guailoudou.github.io/OPL_flutter/data/sponsors.json` |
| 软件更新 | `server/src/data/releases.json` | `https://guailoudou.github.io/OPL_flutter/data/releases.json` |

客户端的基础地址只能填写到仓库名这一层：

```text
https://guailoudou.github.io/OPL_flutter
```

不要填写成：

```text
https://guailoudou.github.io/OPL_flutter/data
https://guailoudou.github.io/OPL_flutter/data/releases.json
```

否则客户端会再次拼接 `/data/*.json`，形成错误路径。

## 2. 为什么推荐 GitHub Actions，而不是直接选择分支目录

GitHub Pages 的分支发布方式通常只能选择分支根目录或 `/docs`。本项目的数据实际保存在：

```text
server/src/data
```

为了避免复制两份 JSON，推荐使用 GitHub Actions：

1. 监听 `server/src/data` 的提交；
2. 验证四个 JSON 的语法；
3. 把 `server/src/data` 复制为 Pages 站点中的 `/data`；
4. 自动部署到 GitHub Pages。

这样仓库中仍然只有一份数据源。

## 3. 创建 GitHub Pages 自动部署工作流

在仓库中创建文件：

```text
.github/workflows/deploy-json-pages.yml
```

填入以下完整内容：

```yaml
name: Deploy JSON data to GitHub Pages

on:
  push:
    branches:
      - main
    paths:
      - "server/src/data/**"
      - ".github/workflows/deploy-json-pages.yml"
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: github-pages
  cancel-in-progress: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}

    steps:
      - name: Checkout
        uses: actions/checkout@v6

      - name: Validate JSON files
        run: |
          for file in server/src/data/*.json; do
            echo "Validating $file"
            jq empty "$file"
          done

      - name: Prepare Pages files
        run: |
          mkdir -p _site/data
          cp server/src/data/*.json _site/data/
          touch _site/.nojekyll
          printf '%s\n' '<!doctype html><html><body><h1>OPL JSON data</h1></body></html>' > _site/index.html

      - name: Configure GitHub Pages
        uses: actions/configure-pages@v5

      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v4
        with:
          path: _site

      - name: Deploy GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

工作流只发布以下内容：

```text
_site/
├── .nojekyll
├── index.html
└── data/
    ├── notices.json
    ├── preset.json
    ├── releases.json
    └── sponsors.json
```

不会把 Flutter 源码、服务端源码或密钥发布到 Pages。

## 4. 在 GitHub 仓库中启用 Pages

提交并推送工作流后：

1. 打开 `https://github.com/Guailoudou/OPL_flutter`；
2. 进入 `Settings`；
3. 在左侧选择 `Pages`；
4. 找到 `Build and deployment`；
5. 将 `Source` 选择为 `GitHub Actions`；
6. 进入仓库的 `Actions` 页面；
7. 打开 `Deploy JSON data to GitHub Pages`；
8. 等待工作流完成，或者点击 `Run workflow` 手动运行。

GitHub Pages 第一次部署或更新可能需要几分钟。GitHub 官方说明发布过程最长可能需要约 10 分钟，不应在刚推送后立即判断为失败。

如果仓库使用 GitHub Free，为保持零成本和最简单的 Pages 使用方式，仓库应保持公开。不要在 JSON 或仓库中放置密码、Token、私钥、数据库账号等敏感信息。

## 5. 修改客户端基础地址

打开：

```text
lib/src/core/url_config.dart
```

将当前局域网默认值：

```dart
static const String defaultApiBase = 'http://192.168.3.194:3000';
```

改为 GitHub Pages 地址：

```dart
static const String defaultApiBase =
    'https://guailoudou.github.io/OPL_flutter';
```

客户端会自动拼接：

```text
/data/preset.json
/data/notices.json
/data/sponsors.json
/data/releases.json
```

基础地址末尾即使带 `/`，客户端也会自动删除多余斜杠。

修改后重新构建应用：

```powershell
flutter build apk --release
```

Windows 版本使用：

```powershell
flutter build windows --release
```

## 6. 旧客户端的 `set.json` 地址覆盖问题

应用会把基础地址写入本地 `set.json`：

```json
{
  "apiBase": "http://192.168.3.194:3000"
}
```

已经运行过的客户端可能继续读取旧地址，从而覆盖源码中新的 `defaultApiBase`。

处理方式：

### Android

开发测试阶段可以：

1. 卸载旧应用后重新安装；或
2. 打开 Android 系统设置；
3. 进入应用信息；
4. 选择存储；
5. 清除应用数据。

### Windows

关闭应用后，找到应用配置目录中的 `OPL/set.json`，把 `apiBase` 改为：

```json
"apiBase": "https://guailoudou.github.io/OPL_flutter"
```

也可以删除 `set.json`，让程序下次启动时重新创建。

正式发布新版本时，推荐在客户端增加一次性迁移逻辑，把旧局域网地址自动替换为 GitHub Pages 地址，避免要求每位用户手动清理数据。

## 7. 更新 JSON 的日常流程

以后不需要登录服务器，只需要修改：

```text
server/src/data/notices.json
server/src/data/preset.json
server/src/data/sponsors.json
server/src/data/releases.json
```

然后提交并推送：

```powershell
git add server/src/data
git commit -m '更新在线 JSON 数据'
git push origin main
```

GitHub Actions 会自动验证并发布文件。若 JSON 语法错误，工作流会在 `Validate JSON files` 步骤失败，旧版本 Pages 内容会继续保留，不会发布损坏数据。

如果只在 GitHub 网页上编辑文件，也会触发相同的部署流程。

## 8. JSON 格式要求

文件名区分大小写，必须保持：

```text
notices.json
preset.json
releases.json
sponsors.json
```

所有文件必须满足：

- 使用 UTF-8 编码；
- 是合法 JSON，不能写 `//` 或 `/* */` 注释；
- 根节点必须是 JSON 对象 `{}`；
- 字符串中的换行写为 `\n`；
- 最后一个字段后不能带逗号；
- 不得包含密码、密钥或其他隐私数据。

本地批量验证：

```powershell
Get-ChildItem 'server/src/data/*.json' | ForEach-Object {
  $null = Get-Content -Raw -Encoding UTF8 $_.FullName | ConvertFrom-Json
  Write-Output "JSON 正常：$($_.Name)"
}
```

## 9. Android 更新：JSON 放 Pages，APK 放 GitHub Releases

推荐分工：

- `releases.json`：GitHub Pages；
- APK、Windows 安装包等大文件：GitHub Releases；
- `releases.json` 中保存 Release 资源的下载地址和 SHA256。

不建议把 APK 直接提交到 Git 仓库或 Pages：大文件会增大仓库，并消耗 Pages 站点容量和流量。GitHub Pages 官方目前给出的站点上限为 1 GB，并有每月 100 GB 的软流量限制；下载产物更适合 GitHub Releases。

创建 GitHub Release 后，APK 地址格式通常为：

```text
https://github.com/Guailoudou/OPL_flutter/releases/download/v0.2.0/opl-0.2.0.apk
```

`server/src/data/releases.json` 示例：

```json
{
  "app": {
    "version": "0.2.0",
    "buildNumber": 3,
    "changelog": "修复问题并优化 Android 体验",
    "url": {
      "windows": "https://github.com/Guailoudou/OPL_flutter/releases/download/v0.2.0/opl-0.2.0.exe",
      "linux": "",
      "macos": "",
      "android": "https://github.com/Guailoudou/OPL_flutter/releases/download/v0.2.0/opl-0.2.0.apk"
    },
    "hash": {
      "windows": "Windows文件SHA256",
      "linux": "",
      "macos": "",
      "android": "APK文件SHA256"
    }
  }
}
```

计算 APK SHA256：

```powershell
Get-FileHash `
  'build/app/outputs/flutter-apk/app-release.apk' `
  -Algorithm SHA256
```

Android 更新必须同时满足：

1. `version` 高于客户端当前版本；
2. `buildNumber` 或 APK 的 `versionCode` 持续递增；
3. APK 使用与旧版本相同的签名证书；
4. `url.android` 可以从手机直接下载；
5. `hash.android` 与最终上传的 APK 完全一致；
6. 用户允许当前应用安装未知来源 APK。

`placeholder_hash` 会使客户端跳过校验，只能用于开发测试，正式发布必须替换成真实 SHA256。

## 10. GitHub Pages 地址验证

工作流成功后，先在浏览器打开：

```text
https://guailoudou.github.io/OPL_flutter/data/releases.json
```

然后在 PowerShell 中验证四个文件：

```powershell
$jsonBase = 'https://guailoudou.github.io/OPL_flutter/data'

@('preset', 'notices', 'sponsors', 'releases') | ForEach-Object {
  $url = "$jsonBase/$_.json"
  $response = Invoke-WebRequest -UseBasicParsing $url
  $null = $response.Content | ConvertFrom-Json
  Write-Output "$url -> HTTP $($response.StatusCode)"
}
```

预期全部返回 HTTP 200。之后在应用中验证：

1. 预设页面能够加载 `preset.json`；
2. 公告页面能够加载 `notices.json`；
3. “我的”页面能够加载 `sponsors.json`；
4. 设置页面检查更新能够读取 `releases.json`；
5. Android 有新版本时能够下载 APK 并打开系统安装界面。

## 11. 缓存和生效时间

GitHub Pages 和中间 CDN 可能缓存文件。推送新 JSON 后：

1. 先确认 GitHub Actions 已成功；
2. 等待几分钟；
3. 用浏览器无痕窗口打开 JSON；
4. 确认响应内容已经更新；
5. 再在客户端刷新。

不要在同一分钟内连续发布很多次。Pages 有构建和部署限制，合并修改后一次推送更稳定。

## 12. 常见问题

### Pages 返回 404

检查：

1. `Settings → Pages → Source` 是否为 `GitHub Actions`；
2. Actions 工作流是否成功；
3. 地址中是否包含仓库名 `/OPL_flutter`；
4. 文件名大小写是否正确；
5. 请求路径是否包含 `/data/`。

正确地址：

```text
https://guailoudou.github.io/OPL_flutter/data/releases.json
```

### 返回的是 GitHub 的 HTML 页面

通常是 Pages 尚未启用、工作流失败或 URL 写错。JSON 响应正文应该以 `{` 开头，而不是 `<!DOCTYPE html>`。

### Actions 中没有 Pages 部署权限

确认工作流包含：

```yaml
permissions:
  contents: read
  pages: write
  id-token: write
```

并确认仓库 Pages 来源选择了 `GitHub Actions`。

### 修改 JSON 后应用仍显示旧数据

依次检查：

1. Actions 是否成功；
2. 浏览器中的 Pages JSON 是否已经更新；
3. 客户端 `set.json` 是否仍指向局域网地址；
4. 客户端是否已经重新构建或清除旧配置；
5. 是否仍处于 GitHub Pages/CDN 缓存时间内。

### Android 能读取 JSON，但 APK 下载失败

Pages 只负责 `releases.json`。检查 `url.android` 指向的 GitHub Release 是否存在、Release 是否公开、资源名称是否完全一致。

### Android APK 无法覆盖安装

检查包名、签名证书和 `versionCode`。从不同电脑使用不同 debug 签名构建的 APK 通常不能互相覆盖，正式发布应固定并妥善备份 release keystore。

## 13. 零成本方案总结

```text
server/src/data/*.json
        │
        │ git push
        ▼
GitHub Actions 校验并部署
        │
        ▼
GitHub Pages: /OPL_flutter/data/*.json
        │
        ▼
Flutter 客户端读取

APK/桌面安装包
        │
        ▼
GitHub Releases
        │
        ▼
releases.json 保存下载 URL 和 SHA256
```

日常维护只需要修改 JSON、提交并推送。Node 服务和管理后台可以保留作为本地编辑工具，但不再是客户端读取数据的必要条件。
