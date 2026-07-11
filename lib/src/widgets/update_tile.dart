import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/update_service.dart';
import 'update_progress_dialog.dart';

class UpdateTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final UpdateComponent component;

  const UpdateTile({
    super.key,
    required this.icon,
    required this.title,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final updateService = context.watch<UpdateService>();
    final state = updateService.getState(component);
    final installedVersion = updateService.getInstalledVersion(component);
    final latestVersion = updateService.getLatestVersion(component);
    final progress = updateService.getProgress(component);

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        installedVersion != null && installedVersion.isNotEmpty
            ? '当前：$installedVersion'
            : '未安装',
      ),
      trailing: _buildTrailing(context, updateService, state, latestVersion, progress),
    );
  }

  Widget _buildTrailing(
    BuildContext context,
    UpdateService service,
    UpdateState state,
    String? latestVersion,
    double progress,
  ) {
    switch (state) {
      case UpdateState.checking:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );

      case UpdateState.downloading:
      case UpdateState.extracting:
        return Text(
          '${(progress * 100).toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 12),
        );

      case UpdateState.updateAvailable:
        return FilledButton(
          onPressed: () => _startDownload(context, service),
          child: Text(latestVersion != null ? '更新到 $latestVersion' : '更新'),
        );

      case UpdateState.upToDate:
        return const Text(
          '已是最新',
          style: TextStyle(color: Colors.green, fontSize: 12),
        );

      case UpdateState.error:
        return TextButton(
          onPressed: () => _startDownload(context, service),
          child: const Text('重试'),
        );

      case UpdateState.idle:
      default:
        final installedVersion = service.getInstalledVersion(component);
        if (installedVersion == null || installedVersion.isEmpty) {
          return FilledButton(
            onPressed: () => _startDownload(context, service),
            child: const Text('安装'),
          );
        }
        return TextButton(
          onPressed: () => _checkUpdate(context, service),
          child: const Text('检查更新'),
        );
    }
  }

  Future<void> _startDownload(BuildContext context, UpdateService service) async {
    final title = component == UpdateComponent.app
        ? '下载应用更新'
        : component == UpdateComponent.core
            ? '下载核心'
            : '下载 EasyTier';

    await UpdateProgressDialog.show(
      context: context,
      title: title,
      downloadTask: (onProgress) => service.downloadAndInstall(component, onProgress: onProgress),
    );
  }

  Future<void> _checkUpdate(BuildContext context, UpdateService service) async {
    await service.checkAllUpdates();
  }
}
