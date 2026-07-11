import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings_models.dart';
import '../../state/app_controller.dart';
import '../../utils/logger.dart';
import '../../services/isp_warning_service.dart';
import '../../services/windows_defender_service.dart';
import '../../services/update_service.dart';
import '../../widgets/update_tile.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final themeMode = controller.settings.themeMode;
    final coreVersion = controller.coreVersion ?? '未安装';
    final runInBackground = controller.settings.runInBackground;
    final askBeforeMinimize = controller.settings.askBeforeMinimize;
    final useGiteeMirror = controller.settings.useGiteeMirror;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // Gitee mirror setting
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('启用 Gitee 镜像'),
            subtitle: const Text('使用 Gitee 镜像加速资源下载'),
            trailing: Switch(
              value: useGiteeMirror,
              onChanged: (value) async {
                L.d('useGiteeMirror: $useGiteeMirror -> $value', tag: 'settings');
                
                await controller.setUseGiteeMirror(value);
                
                L.d('Updated to $value', tag: 'settings');
              },
            ),
          ),
          const Divider(height: 1),
          // Background run setting (Windows only)
          if (Platform.isWindows) ...[
            ListTile(
              leading: const Icon(Icons.minimize),
              title: const Text('关闭时最小化到托盘'),
              subtitle: const Text('点击关闭按钮时最小化到系统托盘而非完全退出'),
              trailing: Switch(
                value: runInBackground,
                onChanged: (value) async {
                  L.d('runInBackground: $runInBackground -> $value', tag: 'settings');
                  
                  await controller.settingsStore.save(
                    controller.settings.copyWith(runInBackground: value),
                  );
                  
                  // Update controller settings
                  controller.settings = controller.settings.copyWith(runInBackground: value);
                  controller.notifyListeners();
                  
                  L.d('Updated to $value', tag: 'settings');
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('询问是否最小化'),
              subtitle: const Text('关闭时弹窗询问，之后按选择执行'),
              trailing: Switch(
                value: askBeforeMinimize,
                onChanged: (value) async {
                  L.d('askBeforeMinimize: $askBeforeMinimize -> $value', tag: 'settings');
                  
                  await controller.settingsStore.save(
                    controller.settings.copyWith(askBeforeMinimize: value),
                  );
                  
                  // Update controller settings
                  controller.settings = controller.settings.copyWith(askBeforeMinimize: value);
                  controller.notifyListeners();
                  
                  L.d('Updated to $value', tag: 'settings');
                },
              ),
            ),
            const Divider(height: 1),
          ],
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
            leading: const Icon(Icons.power_settings_new),
            title: const Text('开机自启动'),
            subtitle: const Text('系统启动时自动运行程序'),
            trailing: Switch(
              value: controller.settings.autoStart,
              onChanged: (value) async {
                L.d('autoStart: ${controller.settings.autoStart} -> $value', tag: 'settings');
                
                try {
                  if (value) {
                    await controller.autoStartService.enable();
                  } else {
                    await controller.autoStartService.disable();
                  }
                  
                  await controller.settingsStore.save(
                    controller.settings.copyWith(autoStart: value),
                  );
                  
                  controller.settings = controller.settings.copyWith(autoStart: value);
                  controller.notifyListeners();
                  
                  L.d('Updated to $value', tag: 'settings');
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(value ? '已启用开机自启动' : '已禁用开机自启动')),
                    );
                  }
                } catch (e) {
                  L.e('设置开机自启动失败: $e', tag: 'settings');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('设置失败: $e')),
                    );
                  }
                }
              },
            ),
          ),
          const Divider(height: 1),
          UpdateTile(
            icon: Icons.phone_android,
            title: '应用版本',
            component: UpdateComponent.app,
          ),
          const Divider(height: 1),
          UpdateTile(
            icon: Icons.memory,
            title: '核心版本',
            component: UpdateComponent.core,
          ),
          const Divider(height: 1),
          UpdateTile(
            icon: Icons.hub,
            title: 'EasyTier 组网核心',
            component: UpdateComponent.easytier,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.network_wifi),
            title: const Text('运营商检测'),
            subtitle: const Text('检测当前网络运营商并提示非主流运营商'),
            trailing: TextButton(
              onPressed: () async {
                if (!context.mounted) return;

                try {
                  final ispService = IspWarningService();
                  final ispInfo = await ispService.fetchIspInfo(forceRefresh: true);

                  if (!context.mounted) return;

                  if (ispInfo == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('获取运营商信息失败')),
                    );
                    return;
                  }

                  final isMainstream = ispService.isMainstreamIsp(ispInfo.isp);

                  showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(isMainstream ? '运营商检测' : '运营商警告'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('IP 地址：${ispInfo.ip}'),
                          Text('运营商：${ispInfo.isp}'),
                          if (ispInfo.region != null) Text('地区：${ispInfo.region}'),
                          if (ispInfo.city != null) Text('城市：${ispInfo.city}'),
                          const SizedBox(height: 12),
                          if (isMainstream)
                            const Text(
                              '✓ 检测到主流运营商，网络连接质量良好',
                              style: TextStyle(color: Colors.green),
                            )
                          else
                            Text(
                              ispService.getWarningMessage(ispInfo.isp),
                              style: const TextStyle(color: Colors.orange),
                            ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  L.e('运营商检测失败: $e', tag: 'settings');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('检测失败: $e')),
                    );
                  }
                }
              },
              child: const Text('检测'),
            ),
          ),
          if (Platform.isWindows) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Windows Defender 排除'),
              subtitle: const Text('将程序添加到杀毒软件排除列表，防止误删'),
              trailing: TextButton(
                onPressed: () async {
                  if (!context.mounted) return;

                  try {
                    final defenderService = WindowsDefenderService();
                    final hasAdmin = await defenderService.hasAdminPrivileges();

                    if (!hasAdmin) {
                      if (!context.mounted) return;
                      showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('需要管理员权限'),
                          content: const Text('此操作需要以管理员身份运行程序'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('确定'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    final isExcluded = await defenderService.isExcluded();

                    if (!context.mounted) return;

                    if (isExcluded) {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('移除排除项'),
                          content: const Text('程序已在 Windows Defender 排除列表中，是否移除？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('移除'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await defenderService.removeExclusion();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已移除 Windows Defender 排除项')),
                          );
                        }
                      }
                    } else {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('添加排除项'),
                          content: const Text('将程序添加到 Windows Defender 排除列表，防止被误删？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('添加'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await defenderService.addExclusion();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已添加 Windows Defender 排除项')),
                          );
                        }
                      }
                    }
                  } catch (e) {
                    L.e('Windows Defender 排除设置失败: $e', tag: 'settings');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('设置失败: $e')),
                      );
                    }
                  }
                },
                child: const Text('设置'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

