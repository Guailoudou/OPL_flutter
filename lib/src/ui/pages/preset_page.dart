import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config_models.dart';
import '../../core/preset_models.dart';
import '../../core/preset_service.dart';
import '../../state/app_controller.dart';

class PresetPage extends StatefulWidget {
  const PresetPage({super.key});

  @override
  State<PresetPage> createState() => _PresetPageState();
}

class _PresetPageState extends State<PresetPage> {
  final _service = PresetService();
  List<PresetTunnel>? _presets;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final response = await _service.fetchPresets();
    if (!mounted) return;
    if (response == null) {
      setState(() {
        _loading = false;
        _error = '无法获取预设列表';
      });
    } else {
      setState(() {
        _loading = false;
        _presets = response.presets;
      });
    }
  }

  Future<void> _addPresetAsTunnel(PresetTunnel preset) async {
    final controller = context.read<AppController>();
    final cfg = controller.config;
    if (cfg == null) return;

    // 获取UID输入
    final uidController = TextEditingController(text: cfg.network.node);
    final uid = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('添加预设：${preset.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (preset.note.isNotEmpty) ...[
                Text(preset.note, style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: uidController,
                decoration: const InputDecoration(
                  labelText: 'UID',
                  hintText: '输入您的UID',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, uidController.text.trim()),
            child: const Text('下一步'),
          ),
        ],
      ),
    );

    if (uid == null || uid.isEmpty) return;

    // 为每个隧道配置创建隧道
    final tunnels = <AppTunnel>[];
    for (final tunnelConfig in preset.tunnel) {
      tunnels.add(AppTunnel(
        appName: '${preset.name}-${tunnelConfig.type.toUpperCase()}${tunnelConfig.cport}',
        protocol: tunnelConfig.type,
        underlayProtocol: '',
        punchPriority: 0,
        whitelist: '',
        srcPort: tunnelConfig.sport,
        peerNode: '',
        dstPort: tunnelConfig.cport,
        dstHost: 'localhost',
        peerUser: uid,
        relayNode: '',
        forceRelay: 0,
        enabled: 0,
      ));
    }

    // 添加隧道
    for (final tunnel in tunnels) {
      await controller.upsertTunnel(tunnel);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 ${tunnels.length} 个隧道')),
      );
      // 返回上一页
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('预设隧道'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loadPresets,
            icon: const Icon(Icons.refresh),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadPresets, child: const Text('重试')),
          ],
        ),
      );
    }
    final presets = _presets ?? [];
    if (presets.isEmpty) {
      return const Center(child: Text('暂无预设'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: presets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final preset = presets[i];
        final tunnelSummary = preset.tunnel
            .map((t) => '${t.type.toUpperCase()}:${t.sport}→${t.cport}')
            .join(', ');
        return Card(
          child: ListTile(
            leading: const Icon(Icons.tune),
            title: Text(preset.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (preset.note.isNotEmpty)
                  Text(
                    preset.note,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Text(
                  tunnelSummary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            isThreeLine: preset.note.isNotEmpty,
            trailing: FilledButton.tonal(
              onPressed: () => _addPresetAsTunnel(preset),
              child: const Text('添加'),
            ),
          ),
        );
      },
    );
  }
}
