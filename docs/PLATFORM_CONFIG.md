# 平台特定配置说明

## macOS 配置

为了使应用在 macOS 上支持后台运行，需要修改 `macos/Runner/AppDelegate.swift`：

```swift
import Cocoa
import FlutterMacOS

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false  // 改为 false，关闭窗口时不退出应用
  }
}
```

## Linux 配置

在 Linux 上，需要修改 `linux/my_application.cc` 以支持启动时隐藏窗口：

```c
// 找到 my_application_activate 函数
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // ... 其他配置 ...

  // 修改这一行：
  gtk_widget_realize(GTK_WIDGET(window));  // 使用 realize 而不是 show
  // 原来是：gtk_widget_show(GTK_WIDGET(window));
  
  // ... 其他代码 ...
}
```

## Windows 配置

Windows 不需要额外配置，window_manager 已经完美支持。

## 注意事项

1. **修改原生代码后需要重新编译**
2. **确保在 pubspec.yaml 中添加了 window_manager 依赖**
3. **测试时请确保应用完全重启以应用更改**
