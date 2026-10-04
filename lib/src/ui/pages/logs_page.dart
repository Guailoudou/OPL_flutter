import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

import '../../core/platform_support.dart';
import '../../state/app_controller.dart';
import '../../state/log_store.dart';
import '../../services/log_export_service.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  LogStore? _logs;

  @override
  void initState() {
    super.initState();
    // 监听日志更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final logs = _logs = Provider.of<LogStore>(context, listen: false);
      logs.addListener(_onLogsChanged);
    });
  }

  @override
  void dispose() {
    _logs?.removeListener(_onLogsChanged);
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

  Future<void> _exportLogs() async {
    try {
      final service = LogExportService();
      final path = await service.exportLogs();
      if (!mounted) return;
      if (path == null) throw StateError('No logs available');
      if (PlatformSupport.isMobile) {
        await service.shareLogs(path);
      } else {
        await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                  title: const Text('日志已导出'),
                  content: SelectableText(path),
                  actions: [
                    TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _openFileManager(path);
                        },
                        child: const Text('打开文件夹'))
                  ],
                ));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出失败： $error')));
    }
  }

  Future<void> _openFileManager(String path) async {
    try {
      if (PlatformSupport.isWindows) {
        // 对于Windows，使用/select参数选择文件
        await Process.run('explorer.exe', ['/select,', path]);
      } else if (PlatformSupport.isMacOS) {
        // 对于MacOS，打开包含文件的文件夹
        final dirPath = p.dirname(path);
        await Process.run('open', [dirPath]);
      } else if (PlatformSupport.isLinux) {
        // 对于Linux，打开包含文件的文件夹
        final dirPath = p.dirname(path);
        await Process.run('xdg-open', [dirPath]);
      }
    } catch (e) {
      debugPrint('打开文件管理器失败：$e');
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
          IconButton(
            tooltip: _autoScroll ? '自动滚动已开启' : '自动滚动已关闭',
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
              // 如果开启自动滚动，立即滚动到底部
              if (_autoScroll && _scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            },
            icon: _autoScroll
                ? const Icon(Icons.auto_fix_high)
                : const Icon(Icons.auto_fix_off),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '导出日志',
            onPressed: PlatformSupport.isWeb ? null : _exportLogs,
            icon: const Icon(Icons.download),
          ),
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
