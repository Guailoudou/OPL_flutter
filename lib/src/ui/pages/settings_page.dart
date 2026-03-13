import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings_models.dart';
import '../../state/app_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final themeMode = controller.settings.themeMode;
    final coreVersion = controller.coreVersion ?? '未安装';

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('主题'),
            subtitle: const Text('浅色 / 深色 / 跟随系统'),
            trailing: DropdownButton<AppThemeMode>(
              value: themeMode,
              onChanged: (v) {
                if (v != null) {
                  controller.setTheme(v);
                }
              },
              items: const [
                DropdownMenuItem(
                  value: AppThemeMode.system,
                  child: Text('跟随系统'),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.light,
                  child: Text('浅色'),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.dark,
                  child: Text('深色'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('核心版本'),
            subtitle: Text('当前：$coreVersion'),
            trailing: TextButton(
              onPressed: () async {
                if (!context.mounted) return;
                
                final current = controller.coreVersion;
                if (current == null || current.isEmpty) {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('下载核心'),
                      content: const Text('当前未安装核心，是否立即下载并安装最新版本？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('立即下载'),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirm == true) {
                    try {
                      await controller.coreRunner.ensureCorePresent();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('核心已下载并安装')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('下载失败：$e')),
                        );
                      }
                    }
                  }
                  return;
                }
                
                final msg = await controller.checkCoreVersionStatus();
                if (!context.mounted) return;
                showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('核心版本检查'),
                    content: Text(msg),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('检查更新'),
            ),
          ),
        ],
      ),
    );
  }
}

