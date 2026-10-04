import 'package:flutter/material.dart';

class UpdateProgressDialog extends StatefulWidget {
  final String title;
  final Future<void> Function(void Function(double) onProgress) downloadTask;

  const UpdateProgressDialog({
    super.key,
    required this.title,
    required this.downloadTask,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required Future<void> Function(void Function(double) onProgress)
        downloadTask,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateProgressDialog(
        title: title,
        downloadTask: downloadTask,
      ),
    );
  }

  @override
  State<UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<UpdateProgressDialog> {
  double _progress = 0.0;
  bool _completed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      await widget.downloadTask((progress) {
        if (mounted) {
          setState(() {
            _progress = progress;
          });
        }
      });

      if (mounted) {
        setState(() {
          _completed = true;
          _progress = 1.0;
        });

        // Auto close after 1 second
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              '下载失败',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (_completed) ...[
            const Icon(Icons.check_circle_outline,
                color: Colors.green, size: 48),
            const SizedBox(height: 16),
            Text(
              '处理完成',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ] else ...[
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              minHeight: 8,
            ),
            const SizedBox(height: 16),
            Text(
              _progress > 0
                  ? '${(_progress * 100).toStringAsFixed(1)}%'
                  : '准备下载...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: () {
              setState(() {
                _error = null;
                _progress = 0.0;
              });
              _startDownload();
            },
            child: const Text('重试'),
          )
        else if (!_completed)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('后台继续'),
          ),
      ],
    );
  }
}
