import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';

import '../../core/platform_paths.dart';
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

  Future<void> _exportLogs() async {
    try {
      // 显示加载对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          title: Text('导出中'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在导出日志文件...'),
            ],
          ),
        ),
      );

      // 获取OPL目录
      final oplDir = await PlatformPaths.configDir();
      if (!await oplDir.exists()) {
        throw Exception('OPL目录不存在');
      }

      // 获取执行目录
      final execDir = Directory.current;

      // 创建压缩文件名
      final timestamp = DateTime.now().toString().replaceAll(RegExp(r'[\/:]'), '-');
      final zipFileName = 'opl_logs_$timestamp.zip';
      final zipFile = File(p.join(execDir.path, zipFileName));

      // 创建压缩文件
      final archive = Archive();

      // 递归添加OPL目录中的所有文件
      await _addDirectoryToArchive(oplDir, archive, 'OPL');

      // 生成压缩数据
      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) {
        throw Exception('压缩失败');
      }

      // 写入压缩文件
      await zipFile.writeAsBytes(zipData);

      // 关闭加载对话框
      Navigator.of(context).pop();

      // 显示成功对话框
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('导出成功'),
          content: Text('日志已导出到：${zipFile.path}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                // 打开文件管理器
                await _openFileManager(zipFile.path);
              },
              child: const Text('打开文件夹'),
            ),
          ],
        ),
      );
    } catch (e) {
      // 关闭加载对话框
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 显示错误对话框
      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('导出失败'),
            content: Text('导出日志时出错：$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _addDirectoryToArchive(Directory dir, Archive archive, String basePath) async {
    final files = await dir.list(recursive: true).toList();
    for (final file in files) {
      if (file is File) {
        final fileName = p.basename(file.path);
        // 排除核心文件
        if (fileName == 'openp2p-opl.exe' || fileName == 'openp2p-opl') {
          continue;
        }
        final archivePath = p.join(basePath, p.relative(file.path, from: dir.path));
        final content = await file.readAsBytes();
        final archiveFile = ArchiveFile(archivePath, content.length, content);
        archive.addFile(archiveFile);
      }
    }
  }

  Future<void> _openFileManager(String path) async {
    try {
      if (Platform.isWindows) {
        // 对于Windows，使用/select参数选择文件
        await Process.run('explorer.exe', ['/select,', path]);
      } else if (Platform.isMacOS) {
        // 对于MacOS，打开包含文件的文件夹
        final dirPath = p.dirname(path);
        await Process.run('open', [dirPath]);
      } else if (Platform.isLinux) {
        // 对于Linux，打开包含文件的文件夹
        final dirPath = p.dirname(path);
        await Process.run('xdg-open', [dirPath]);
      }
    } catch (e) {
      print('打开文件管理器失败：$e');
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
            icon: _autoScroll ? const Icon(Icons.auto_fix_high) : const Icon(Icons.auto_fix_off),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '导出日志',
            onPressed: _exportLogs,
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

