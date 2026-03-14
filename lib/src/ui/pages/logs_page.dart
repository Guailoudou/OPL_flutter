import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../state/log_store.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    // 监听日志更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final logs = Provider.of<LogStore>(context, listen: false);
      logs.addListener(_onLogsChanged);
    });
  }

  @override
  void dispose() {
    final logs = Provider.of<LogStore>(context, listen: false);
    logs.removeListener(_onLogsChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogsChanged() {
    if (_autoScroll && _scrollController.hasClients) {
      // 延迟一点确保 UI 已经更新
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<LogStore>();
    final controller = context.watch<AppController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('日志'),
        actions: [
          // 自动滚动开关
          Switch(
            value: _autoScroll,
            onChanged: (value) {
              setState(() {
                _autoScroll = value;
              });
              // 如果开启自动滚动，立即滚动到底部
              if (value && _scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            },
          ),
          Tooltip(
            message: _autoScroll ? '自动滚动已开启' : '自动滚动已关闭',
            child: const Icon(Icons.auto_awesome_motion),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '清空',
            onPressed: logs.clear,
            icon: const Icon(Icons.delete_sweep),
          ),
          if (controller.coreRunning)
            IconButton(
              tooltip: '停止核心',
              onPressed: controller.stopCore,
              icon: const Icon(Icons.stop),
            ),
        ],
      ),
      body: logs.lines.isEmpty
          ? const Center(child: Text('暂无日志'))
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: logs.lines.length,
              itemBuilder: (_, i) {
                final line = logs.lines[i];
                return SelectableText(
                  line,
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
    );
  }
}

