## OPL Config Manager

跨平台（桌面/移动）P2P 核心配置管理器（`config.json`）。

### 你需要先生成平台工程

此仓库目前只包含业务代码与依赖定义。请在本机 Flutter 环境执行：

```bash
flutter create .
flutter pub get
flutter run
```

### 配置文件路径规则

- 桌面端：可执行文件同级 `OPL/config.json`
- 移动端：应用文档目录（包名对应沙盒目录）`config.json`

