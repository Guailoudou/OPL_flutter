import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/app_controller.dart';

class MePage extends StatelessWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final cfg = controller.config;
    if (cfg == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('UID（Network.Node）', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  SelectableText(cfg.network.node, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text('共享带宽（ShareBandwidth）：${cfg.network.shareBandwidth}'),
                      ),
                      FilledButton.tonal(
                        onPressed: () async {
                          if (controller.coreRunning) {
                            await _showConfigLockedDialog(context);
                            return;
                          }
                          final updated = await _editIntDialog(
                            context,
                            title: '编辑共享带宽',
                            initial: cfg.network.shareBandwidth,
                          );
                          if (updated != null) {
                            await controller.updateShareBandwidth(updated);
                          }
                        },
                        child: const Text('编辑'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () async {
                      if (controller.coreRunning) {
                        await _showConfigLockedDialog(context);
                        return;
                      }
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('重置 UID'),
                          content: const Text('此操作会生成新的 UID，可能导致现有连接失效。确认继续？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('确认重置'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await controller.resetUid();
                      }
                    },
                    child: const Text('重置 UID'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('关于'),
              subtitle: const Text('版本信息 / 作者 / Bug 反馈'),
              onTap: () async {
                final info = await PackageInfo.fromPlatform();
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('关于'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('应用：${info.appName}'),
                        Text('版本：${info.version}+${info.buildNumber}'),
                        const SizedBox(height: 10),
                        const Text('作者：Guailoudou'),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () async {
                            final url = Uri.parse('https://space.bilibili.com/496960407');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                          child: const Text(
                            '作者 B 站：https://space.bilibili.com/496960407',
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () async {
                            final url = Uri.parse('https://github.com/your-repo/issues');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                          child: const Text(
                            'Bug 反馈：点击打开 Issue 页面',
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<int?> _editIntDialog(
  BuildContext context, {
  required String title,
  required int initial,
}) async {
  final c = TextEditingController(text: initial.toString());
  final v = await showDialog<int?>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          onPressed: () {
            c.dispose();
            Navigator.pop(context, null);
          },
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(c.text.trim());
            c.dispose();
            Navigator.pop(context, value);
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
  return v;
}

Future<void> _showConfigLockedDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('不可编辑'),
      content: const Text('核心运行期间禁止修改 config.json，请先停止核心。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

