import '../../services/update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../services/external_link_service.dart';

import '../../core/platform_support.dart';
import '../../core/sponsor_models.dart';
import '../../core/sponsor_service.dart';
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
                  Text('UID（Network.Node）',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  SelectableText(cfg.network.node,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            '共享带宽（ShareBandwidth）：${cfg.network.shareBandwidth}'),
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
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            if (controller.coreRunning) {
                              await _showConfigLockedDialog(context);
                              return;
                            }
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('重置 UID'),
                                content:
                                    const Text('此操作会生成新的 UID，可能导致现有连接失效。确认继续？'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            if (controller.coreRunning) {
                              await _showConfigLockedDialog(context);
                              return;
                            }
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('重置程序'),
                                content: const Text(
                                    '此操作会停止核心、删除已下载的核心并重置配置与设置。确认继续？'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('确认重置'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true && context.mounted) {
                              await controller.resetApp(context);
                            }
                          },
                          child: const Text('重置程序'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.favorite_outline),
              title: const Text('赞助名单'),
              subtitle: const Text('感谢所有赞助者'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SponsorListPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('关于'),
              subtitle: const Text('版本信息 / 作者 / Bug 反馈'),
              onTap: () async {
                PackageInfo info = PackageInfo(
                  appName: 'OPL',
                  packageName: 'top.gldhn.opl_ohos',
                  version: controller.updateService
                          .getInstalledVersion(UpdateComponent.app) ??
                      '0.1.0',
                  buildNumber: '1',
                );
                try {
                  if (!PlatformSupport.isOhos) {
                    info = await PackageInfo.fromPlatform();
                  }
                } on MissingPluginException {
                  // package_info_plus has no OHOS implementation yet.
                }
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
                            final url = Uri.parse(
                                'https://space.bilibili.com/496960407');
                            await openExternalLink(url);
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
                            final url = Uri.parse(
                                'https://github.com/Guailoudou/OPL_flutter/issues');
                            await openExternalLink(url);
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

class SponsorListPage extends StatefulWidget {
  const SponsorListPage({super.key});

  @override
  State<SponsorListPage> createState() => _SponsorListPageState();
}

class _SponsorListPageState extends State<SponsorListPage> {
  final SponsorService _sponsorService = SponsorService();
  List<Sponsor> _sponsors = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSponsors();
  }

  Future<void> _loadSponsors() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _sponsorService.fetchSponsors();
      if (mounted) {
        setState(() {
          _sponsors = response?.sponsors ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('赞助名单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSponsors,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('加载失败: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSponsors,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_sponsors.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无赞助记录'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sponsors.length,
      itemBuilder: (context, index) {
        final sponsor = _sponsors[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sponsor.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '¥${sponsor.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (sponsor.message != null && sponsor.message!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    sponsor.message!,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  sponsor.time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
