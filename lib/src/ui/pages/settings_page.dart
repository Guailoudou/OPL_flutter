import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/settings_models.dart';
import '../../core/platform_support.dart';
import '../../state/app_controller.dart';
import '../../utils/logger.dart';
import '../../services/isp_warning_service.dart';
import '../../services/windows_defender_service.dart';
import '../../services/update_service.dart';
import '../../widgets/update_tile.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _setKeepAlive(
      BuildContext context, AppController controller, bool enabled,
      {bool pictureInPicture = false}) async {
    try {
      await controller.setOhosKeepAlive(enabled,
          pictureInPicture: pictureInPicture);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final themeMode = controller.settings.themeMode;
    final runInBackground = controller.settings.runInBackground;
    final askBeforeMinimize = controller.settings.askBeforeMinimize;
    final useGiteeMirror = controller.settings.useGiteeMirror;
    final token = controller.config?.network.token;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('OpenP2P Token'),
            subtitle: Text(
              token == null || token == BigInt.zero
                  ? '未设置'
                  : '当前：${_maskToken(token.toString())}',
            ),
            trailing: TextButton(
              onPressed: token == null
                  ? null
                  : () async {
                      if (controller.coreRunning) {
                        await _showTokenLockedDialog(context);
                        return;
                      }
                      final updated = await _editTokenDialog(
                        context,
                        initial: token,
                      );
                      if (updated == null || !context.mounted) return;
                      await controller.updateToken(updated);
                      if (!context.mounted) return;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Token 已保存，请重新启动核心'),
                          ),
                        );
                      });
                    },
              child: const Text('设置'),
            ),
          ),
          const Divider(height: 1),
          // Gitee mirror setting
          if (PlatformSupport.isOhos) ...[
            SwitchListTile(
              title: const Text('持续后台运行'),
              subtitle: const Text('核心运行时申请持续后台任务；返回前台或停止核心后释放'),
              value: controller.ohosBackgroundKeepAlive,
              onChanged: (enabled) =>
                  _setKeepAlive(context, controller, enabled),
            ),
            SwitchListTile(
              title: const Text('画中画保活'),
              subtitle: const Text('进入后台时显示小窗，需要设备支持画中画'),
              value: controller.ohosPictureInPicture,
              onChanged: (enabled) => _setKeepAlive(
                  context, controller, enabled,
                  pictureInPicture: true),
            ),
            const Divider(height: 1),
          ],
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('启用 Gitee 镜像'),
            subtitle: const Text('使用 Gitee 镜像加速资源下载'),
            trailing: Switch(
              value: useGiteeMirror,
              onChanged: (value) async {
                L.d('useGiteeMirror: $useGiteeMirror -> $value',
                    tag: 'settings');

                await controller.setUseGiteeMirror(value);

                L.d('Updated to $value', tag: 'settings');
              },
            ),
          ),
          const Divider(height: 1),
          // Background run setting (Windows only)
          if (PlatformSupport.isWindows) ...[
            ListTile(
              leading: const Icon(Icons.minimize),
              title: const Text('关闭时最小化到托盘'),
              subtitle: const Text('点击关闭按钮时最小化到系统托盘而非完全退出'),
              trailing: Switch(
                value: runInBackground,
                onChanged: (value) async {
                  L.d('runInBackground: $runInBackground -> $value',
                      tag: 'settings');

                  await controller.updateSettings(
                    controller.settings.copyWith(runInBackground: value),
                  );

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
                  L.d('askBeforeMinimize: $askBeforeMinimize -> $value',
                      tag: 'settings');

                  await controller.updateSettings(
                    controller.settings.copyWith(askBeforeMinimize: value),
                  );

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
          if (PlatformSupport.isDesktop) ...[
            ListTile(
              leading: const Icon(Icons.power_settings_new),
              title: const Text('开机自启动'),
              subtitle: const Text('系统启动时自动运行程序'),
              trailing: Switch(
                value: controller.settings.autoStart,
                onChanged: (value) async {
                  L.d('autoStart: ${controller.settings.autoStart} -> $value',
                      tag: 'settings');
                  try {
                    if (value) {
                      await controller.autoStartService.enable();
                    } else {
                      await controller.autoStartService.disable();
                    }
                    await controller.updateSettings(
                      controller.settings.copyWith(autoStart: value),
                    );
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
          ],
          UpdateTile(
            icon: Icons.phone_android,
            title: '应用版本',
            component: UpdateComponent.app,
          ),
          if (PlatformSupport.isDesktop) ...[
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
          ],
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
                  final ispInfo =
                      await ispService.fetchIspInfo(forceRefresh: true);

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
                          if (ispInfo.region != null)
                            Text('地区：${ispInfo.region}'),
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
          if (PlatformSupport.isWindows) ...[
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
                          content:
                              const Text('程序已在 Windows Defender 排除列表中，是否移除？'),
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
                            const SnackBar(
                                content: Text('已移除 Windows Defender 排除项')),
                          );
                        }
                      }
                    } else {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('添加排除项'),
                          content:
                              const Text('将程序添加到 Windows Defender 排除列表，防止被误删？'),
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
                            const SnackBar(
                                content: Text('已添加 Windows Defender 排除项')),
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

String _maskToken(String token) {
  if (token.length <= 4) {
    return '••••';
  }
  return '••••••••${token.substring(token.length - 4)}';
}

Future<BigInt?> _editTokenDialog(
  BuildContext context, {
  required BigInt initial,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<BigInt>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _TokenEditorDialog(initial: initial),
  );
  final result = await navigator.push<BigInt>(route);
  await route.completed;
  return result;
}

class _TokenEditorDialog extends StatefulWidget {
  const _TokenEditorDialog({required this.initial});

  final BigInt initial;

  @override
  State<_TokenEditorDialog> createState() => _TokenEditorDialogState();
}

class _TokenEditorDialogState extends State<_TokenEditorDialog> {
  static final BigInt _maxUint64 = (BigInt.one << 64) - BigInt.one;

  late final TextEditingController _controller;
  bool _obscureText = true;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initial == BigInt.zero ? '' : widget.initial.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = BigInt.tryParse(_controller.text.trim());
    if (value == null || value <= BigInt.zero || value > _maxUint64) {
      setState(() {
        _validationError = '请输入 1 到 18446744073709551615 之间的整数';
      });
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置 OpenP2P Token'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            obscureText: _obscureText,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Token（十进制 uint64）',
              border: const OutlineInputBorder(),
              errorText: _validationError,
              suffixIcon: IconButton(
                tooltip: _obscureText ? '显示 Token' : '隐藏 Token',
                onPressed: () {
                  setState(() => _obscureText = !_obscureText);
                },
                icon: Icon(
                  _obscureText ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Token 会写入应用沙箱中的 config.json，请勿截图或分享。'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

Future<void> _showTokenLockedDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('无法修改 Token'),
      content: const Text('核心运行期间不能修改 Token，请先停止核心。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('确定'),
        ),
      ],
    ),
  );
}
