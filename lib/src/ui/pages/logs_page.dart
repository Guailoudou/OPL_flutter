import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../state/log_store.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<LogStore>();
    final controller = context.watch<AppController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('日志'),
        actions: [
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

