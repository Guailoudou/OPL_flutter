import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config_models.dart';
import '../../core/platform_paths.dart';
import '../../state/app_controller.dart';
import '../../state/log_store.dart';
import '../widgets/status_dot.dart';

class TunnelsPage extends StatelessWidget {
  const TunnelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final cfg = controller.config;
    final logs = context.watch<LogStore>();

    if (cfg == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('隧道'),
        actions: [
          IconButton(
            tooltip: '刷新配置',
            onPressed: controller.reloadConfig,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _UidBanner(uid: cfg.network.node),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: cfg.apps.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                if (idx == 0) {
                  return _PathBanner();
                }
                final i = idx - 1;
                final tunnel = cfg.apps[i];
                final status = _resolveStatus(
                  tunnel,
                  logs.lines,
                  controller.coreRunning,
                );
                return _TunnelTile(
                  tunnel: tunnel,
                  status: status,
                  onToggle: (v) async {
                    if (controller.coreRunning) {
                      await _showConfigLockedDialog(context);
                      return;
                    }
                    await controller.toggleTunnelEnabled(i, v);
                  },
                  onAction: (action, tapPosition) async {
                    switch (action) {
                      case _TunnelAction.edit:
                        if (controller.coreRunning) {
                          await _showConfigLockedDialog(context);
                          return;
                        }
                        final updated = await showDialog<AppTunnel>(
                          context: context,
                          builder: (_) => TunnelEditorDialog(initial: tunnel),
                        );
                        if (updated != null) {
                          await controller.upsertTunnel(updated, index: i);
                        }
                        return;
                      case _TunnelAction.copyIp:
                        await Clipboard.setData(
                          ClipboardData(text: tunnel.localLoopback),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已复制：${tunnel.localLoopback}')),
                          );
                        }
                        return;
                      case _TunnelAction.delete:
                        if (controller.coreRunning) {
                          await _showConfigLockedDialog(context);
                          return;
                        }
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('删除隧道'),
                            content: Text('确认删除「${tunnel.appName}」？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await controller.deleteTunnel(i);
                        }
                        return;
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _FabRow(
        onAdd: () async {
          if (controller.coreRunning) {
            await _showConfigLockedDialog(context);
            return;
          }
          final created = await showDialog<AppTunnel>(
            context: context,
            builder: (_) => const TunnelEditorDialog(),
          );
          if (created != null) {
            await controller.upsertTunnel(created);
          }
        },
        onStart: () async {
          try {
            final wasRunning = controller.coreRunning;
            if (wasRunning) {
              await controller.stopCore();
              // Wait a bit to ensure process is killed
              await Future.delayed(const Duration(milliseconds: 500));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已停止核心')),
                );
              }
            } else {
              await controller.startCore();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已启动核心（桌面端）')),
                );
              }
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('操作失败：$e')),
              );
            }
          }
        },
        isRunning: controller.coreRunning,
      ),
    );
  }
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

class _UidBanner extends StatelessWidget {
  const _UidBanner({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final isRunning = controller.coreRunning;
    final isLoggedIn = controller.coreLoggedIn;
    
    Color statusColor;
    if (!isRunning) {
      statusColor = Colors.grey;
    } else if (!isLoggedIn) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.green;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.person),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '我的 UID',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          uid.isEmpty ? '未获取到 UID' : uid,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StatusDot(color: statusColor),
                      const SizedBox(width: 6)
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: '复制 UID',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: uid));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制 UID')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PathBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: PlatformPaths.configFile(),
      builder: (context, snap) {
        final path = snap.data?.path ?? '...';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.folder_open),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'config.json：$path',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

enum _TunnelStatus { disabled, starting, connected }

_TunnelStatus _resolveStatus(
  AppTunnel t,
  List<String> lines,
  bool coreRunning,
) {
  // 核心未运行：一律灰色
  if (!coreRunning) return _TunnelStatus.disabled;
  if (t.enabled != 1) return _TunnelStatus.disabled;

  // 若日志里出现 LISTEN ON PORT <proto>:<srcPort> START，则视为隧道连接成功（绿色）
  final listenTag = 'listen on port';
  final proto = t.protocol.toLowerCase();
  final portStr = t.srcPort.toString();
  for (final line in lines.reversed.take(500)) {
    final l = line.toLowerCase();
    if (!l.contains(listenTag)) continue;
    if (!l.contains(proto)) continue;
    if (!l.contains(':$portStr')) continue;
    if (!l.contains('start')) continue;
    return _TunnelStatus.connected;
  }

  // 已启用但尚未监听：橙色（启动中）
  return _TunnelStatus.starting;
}

Color _statusColor(BuildContext context, _TunnelStatus s) {
  switch (s) {
    case _TunnelStatus.disabled:
      return Colors.grey;
    case _TunnelStatus.starting:
      return Colors.orange;
    case _TunnelStatus.connected:
      return Colors.green;
  }
}

enum _TunnelAction { edit, copyIp, delete }

class _TunnelTile extends StatelessWidget {
  const _TunnelTile({
    required this.tunnel,
    required this.status,
    required this.onToggle,
    required this.onAction,
  });

  final AppTunnel tunnel;
  final _TunnelStatus status;
  final ValueChanged<bool> onToggle;
  final Future<void> Function(_TunnelAction action, Offset tapPosition) onAction;

  @override
  Widget build(BuildContext context) {
    Offset lastTapPos = Offset.zero;

    Future<void> showActions(Offset globalPos) async {
      final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
      final position = RelativeRect.fromRect(
        Rect.fromLTWH(globalPos.dx, globalPos.dy, 1, 1),
        Offset.zero & (overlay?.size ?? const Size(1, 1)),
      );
      final selected = await showMenu<_TunnelAction>(
        context: context,
        position: position,
        items: const [
          PopupMenuItem(value: _TunnelAction.edit, child: Text('编辑')),
          PopupMenuItem(value: _TunnelAction.copyIp, child: Text('复制 IP')),
          PopupMenuItem(value: _TunnelAction.delete, child: Text('删除')),
        ],
      );
      if (selected != null) {
        await onAction(selected, globalPos);
      }
    }

    return GestureDetector(
      onTapDown: (d) => lastTapPos = d.globalPosition,
      onLongPress: () => showActions(lastTapPos),
      onSecondaryTapDown: (d) => showActions(d.globalPosition),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: StatusDot(color: _statusColor(context, status)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tunnel.appName.isEmpty ? '(未命名隧道)' : tunnel.appName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tunnel.protocol.toUpperCase()}  ${tunnel.peerNode}:${tunnel.dstPort}  →  ${tunnel.localLoopback}',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Switch(
                    value: tunnel.enabled == 1,
                    onChanged: (v) => onToggle(v),
                  ),
                  if (PlatformPaths.isDesktop || Platform.isAndroid || Platform.isIOS)
                    IconButton(
                      tooltip: PlatformPaths.isDesktop ? '右键操作' : '长按操作',
                      onPressed: () => showActions(lastTapPos),
                      icon: const Icon(Icons.more_vert),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FabRow extends StatelessWidget {
  const _FabRow({required this.onAdd, required this.onStart, required this.isRunning});

  final VoidCallback onAdd;
  final VoidCallback onStart;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'add',
          onPressed: onAdd,
          child: const Icon(Icons.add),
        ),
        const SizedBox(width: 12),
        FloatingActionButton(
          heroTag: 'start',
          onPressed: onStart,
          child: Icon(isRunning ? Icons.pause : Icons.play_arrow),
        ),
      ],
    );
  }
}

class TunnelEditorDialog extends StatefulWidget {
  const TunnelEditorDialog({super.key, this.initial});

  final AppTunnel? initial;

  @override
  State<TunnelEditorDialog> createState() => _TunnelEditorDialogState();
}

class _TunnelEditorDialogState extends State<TunnelEditorDialog> {
  late final TextEditingController name;
  late String protocol;
  late final TextEditingController srcPort;
  late final TextEditingController peerNode;
  late final TextEditingController dstPort;
  bool enabled = false;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    name = TextEditingController(text: t?.appName ?? '');
    protocol = t?.protocol ?? 'tcp';
    srcPort = TextEditingController(text: (t?.srcPort ?? 0).toString());
    peerNode = TextEditingController(text: t?.peerNode ?? '');
    dstPort = TextEditingController(text: (t?.dstPort ?? 0).toString());
    enabled = (t?.enabled ?? 0) == 1;
    
    dstPort.addListener(() {
      if (srcPort.text != dstPort.text) {
        srcPort.text = dstPort.text;
      }
    });
  }

  @override
  void dispose() {
    name.dispose();
    srcPort.dispose();
    peerNode.dispose();
    dstPort.dispose();
    super.dispose();
  }

  int _toPort(String v) => int.tryParse(v.trim()) ?? 0;

  bool _validateAndSave() {
    final form = _formKey.currentState;
    if (!form!.validate()) return false;
    
    form.save();
    
    if (peerNode.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('远程 UID 不能为空')),
      );
      return false;
    }
    
    if (dstPort.text.trim().isEmpty || _toPort(dstPort.text) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('远程端口不能为空且必须大于 0')),
      );
      return false;
    }
    
    if (srcPort.text.trim().isEmpty || _toPort(srcPort.text) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本地端口不能为空且必须大于 0')),
      );
      return false;
    }
    
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return AlertDialog(
      title: Text(isEdit ? '编辑隧道' : '添加隧道'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Field(
                  label: '隧道名称（AppName）',
                  controller: name,
                  hint: '例如：自定义隧道'
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: protocol,
                  decoration: const InputDecoration(
                    labelText: '协议（Protocol）',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'tcp', child: Text('TCP')),
                    DropdownMenuItem(value: 'udp', child: Text('UDP')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        protocol = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                _Field(
                  label: '远程 UID（PeerNode）*',
                  controller: peerNode,
                  hint: '16 位 0-f（必填）',
                ),
                const SizedBox(height: 10),
                _Field(
                  label: '远程端口（DstPort）*',
                  controller: dstPort,
                  inputType: TextInputType.number,
                  hint: '必填，必须大于 0',
                ),
                const SizedBox(height: 10),
                _Field(
                  label: '本地端口（SrcPort）*',
                  controller: srcPort,
                  inputType: TextInputType.number,
                  hint: '必填，必须大于 0',
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: enabled,
                  onChanged: (v) => setState(() => enabled = v),
                  title: const Text('启用（Enabled）'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (!_validateAndSave()) return;
            
            final base = widget.initial;
            final t = AppTunnel(
              appName: name.text.trim(),
              protocol: protocol,
              underlayProtocol: base?.underlayProtocol ?? '',
              punchPriority: base?.punchPriority ?? 0,
              whitelist: base?.whitelist ?? '',
              srcPort: _toPort(srcPort.text),
              peerNode: peerNode.text.trim(),
              dstPort: _toPort(dstPort.text),
              dstHost: base?.dstHost ?? 'localhost',
              peerUser: base?.peerUser ?? '',
              relayNode: base?.relayNode ?? '',
              forceRelay: base?.forceRelay ?? 0,
              enabled: enabled ? 1 : 0,
            );
            Navigator.pop(context, t);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.inputType,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? inputType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

