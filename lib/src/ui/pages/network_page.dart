import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/easytier_service.dart';
import '../../state/app_controller.dart';
import '../widgets/network_card.dart';

class NetworkPage extends StatefulWidget {
  const NetworkPage({super.key});

  @override
  State<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends State<NetworkPage> {
  late EasyTierService _easyTierService;

  @override
  void initState() {
    super.initState();
    final controller = context.read<AppController>();
    _easyTierService = controller.easyTierService;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final uid = controller.config?.network.node ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('虚拟组网'),
        actions: [
          if (_easyTierService.isRunning)
            IconButton(
              icon: const Icon(Icons.stop),
              tooltip: '停止组网',
              onPressed: _stopNetwork,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEasyTierPanel(uid),
            const SizedBox(height: 16),
            if (_easyTierService.isRunning) _buildNetworkStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildEasyTierPanel(String uid) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'EasyTier 组网',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'EasyTier 是基于虚拟网卡的组网方案，支持多种传输协议，性能更好。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('创建网络'),
                    onPressed: _easyTierService.isRunning
                        ? null
                        : () => _showCreateEasyTierDialog(uid),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.login),
                    label: const Text('加入网络'),
                    onPressed: _easyTierService.isRunning
                        ? null
                        : () => _showJoinEasyTierDialog(uid),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkStatus() {
    return StreamBuilder<List<NetworkNode>>(
      stream: _easyTierService.nodesStream,
      initialData: _easyTierService.nodes,
      builder: (context, snapshot) {
        final nodes = snapshot.data ?? _easyTierService.nodes;
        return NetworkCard(
          networkName: _easyTierService.networkName ?? '',
          localIp: _easyTierService.localIp ?? '',
          isHost: _easyTierService.isHost,
          nodes: nodes,
          onStop: _stopNetwork,
        );
      },
    );
  }

  Future<void> _stopNetwork() async {
    try {
      await _easyTierService.stop();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已停止组网')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('停止失败: $e')),
        );
      }
    }
  }

  Future<void> _showCreateEasyTierDialog(String uid) async {
    final nodeServerController =
        TextEditingController(text: 'tcp://p.gldhn.top:11010');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建 EasyTier 网络'),
        content: TextField(
          controller: nodeServerController,
          decoration: const InputDecoration(
            labelText: '节点服务器地址',
            hintText: 'tcp://节点地址:端口',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nodeServerController.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _easyTierService.createNetwork(
          nodeServer: result,
          networkName: uid,
        );
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('网络创建成功')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('创建失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _showJoinEasyTierDialog(String uid) async {
    final nodeServerController =
        TextEditingController(text: 'tcp://p.gldhn.top:11010');
    final networkNameController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('加入 EasyTier 网络'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nodeServerController,
              decoration: const InputDecoration(
                labelText: '节点服务器地址',
                hintText: 'tcp://节点地址:端口',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: networkNameController,
              decoration: const InputDecoration(
                labelText: '网络名称',
                hintText: '房主提供的网络名称',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, {
                'nodeServer': nodeServerController.text,
                'networkName': networkNameController.text,
              });
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _easyTierService.joinNetwork(
          nodeServer: result['nodeServer']!,
          networkName: result['networkName']!,
        );
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('成功加入网络')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加入失败: $e')),
          );
        }
      }
    }
  }
}
