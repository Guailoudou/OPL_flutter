# 鸿蒙构建流程

当前工程使用 OHOS Flutter 3.27.4 / Dart 3.6.2、HarmonyOS 6.1.1 API 24 和 arm64 OpenP2P 动态库。标准 Flutter 3.41.4 用于其他平台，不与鸿蒙 SDK 共用生成的依赖状态。

## 1. 同步参考核心

参考目录默认为同级 `openp2p-master/ohos`。脚本检查 ELF64 AArch64、接口头文件及 SO/头文件哈希，不修改参考工程。

```powershell
.\scripts\build_openp2p_ohos.ps1 -VerifyOnly
# 参考工程更新后同步：
.\scripts\build_openp2p_ohos.ps1 -ReferenceOhos 'D:\Guail\Documents\openp2p-master\ohos'
```

目标文件：

```text
ohos/entry/libs/arm64-v8a/libopenp2p_ohos.so
ohos/entry/libs/arm64-v8a/libopenp2p_ohos.h
```

必须成对更新。当前 SO 的 SHA-256 为 `85DDC504FD76FA6145F1FBC6988A05A5D8BDC2C4F441E10D7C540D7F8A4F515C`，与参考工程一致。NAPI 层动态加载同名库，并使用运行状态、健康信息、SDWAN 配置与 TUN 接口。

如需重新编译 SO，应遵循参考工程的 OpenHarmony-SIG Go 工具链流程，在 Linux 使用支持 `openharmony/arm64` 的 Go、OHOS Native SDK、`GOOS=openharmony`、`CGO_ENABLED=1` 和 `-buildmode=c-shared`。Windows stock Go 的 `GOOS=linux` 不能生成等价的鸿蒙运行库。桌面核心的 Go 1.20 依赖也不能直接套用另一套工具链版本。

## 2. 配置 SDK 与签名

安装 DevEco Studio、对应 SDK、Node.js/npm 和 DevEco CLI，并准备 OHOS Flutter SDK。

```powershell
$env:HOS_SDK_HOME = 'E:\Program Files\Huawei\DevEco Studio\sdk'
$env:FLUTTER_OHOS = 'E:\Users\Guail\flutter_ohos\bin\flutter.bat'
devecocli --help
```

`ohos/build-profile.template.json5` 是可提交的无签名模板。个人签名配置放在被 Git 忽略的 `ohos/build-profile.json5`，可由 DevEco Studio 配置；证书、私钥和密码不要提交。不存在本地配置时脚本使用公共模板；`--unsigned` 可显式选择模板。

## 3. 构建 HAP

从仓库根目录执行：

```powershell
python scripts/build_ohos.py --build-mode debug
python scripts/build_ohos.py --build-mode release
# 不使用个人签名配置：
python scripts/build_ohos.py --build-mode release --unsigned
```

也可通过 `--flutter <OHOS flutter.bat>` 指定 SDK。脚本在 `.codex_staging/ohos-validation` 复制源码，安装 OHOS Flutter 依赖与 Hvigor 插件，预缓存 engine，再通过 `devecocli build --modules entry` 构建。最终 HAP 复制到 `dist/ohos`，根工程的标准 Flutter 依赖保持独立。

安装有签名 HAP 前需要匹配证书、设备授权与系统 VPN 授权。设备检查使用 `devecocli device list`；无设备时只能验证构建与包内容。

## 4. 运行与保活

VPN Extension 拥有原生核心与 TUN，界面重建时读取已有运行状态；状态文件保存启动参数与保活选项。前后台切换会检查核心健康，异常时按原参数恢复。

保活包含 dataTransfer 连续任务与可选画中画。设置界面可切换，系统拒绝申请时返回失败并恢复原设置。当前未引入位置服务或位置权限。

真机至少验证以下场景：首次 VPN 授权、隧道收发、撤销授权、锁屏后台、清理界面进程、断网恢复、关闭保活和主动停止。不同设备的后台策略可能不同，HAP 编译通过不能替代这些测试。
