import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../core/platform_paths.dart';
import '../core/platform_support.dart';
import '../core/config_store.dart';
import '../utils/logger.dart';
import 'ohos_share_service.dart';

class LogExportService {
  Future<String?> exportLogs() async {
    try {
      L.i('Starting log export', tag: 'log_export');

      final configDir = await PlatformPaths.configDir();
      final logDir = Directory(p.join(configDir.path, 'log'));

      if (!await logDir.exists()) {
        L.w('Log directory not found', tag: 'log_export');
        return null;
      }

      final archive = Archive();

      // 收集日志文件
      final logFiles = await logDir.list().toList();
      for (final entity in logFiles) {
        if (entity is File && entity.path.endsWith('.log')) {
          final content = utf8.encode(_redact(await entity.readAsString()));
          final filename = p.basename(entity.path);
          archive.addFile(ArchiveFile(filename, content.length, content));
          L.d('Added log file: $filename', tag: 'log_export');
        }
      }

      // 添加配置文件
      final configFile = File(p.join(configDir.path, 'config.json'));
      if (await configFile.exists()) {
        final config = ConfigStore.decode(await configFile.readAsString());
        final content = utf8.encode(const JsonEncoder.withIndent('  ').convert(
          config
              .copyWith(network: config.network.copyWith(token: BigInt.zero))
              .toJson(),
        ));
        archive.addFile(ArchiveFile('config.json', content.length, content));
        L.d('Added config.json', tag: 'log_export');
      }

      // 生成 ZIP 文件
      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) {
        L.e('Failed to encode ZIP', tag: 'log_export');
        return null;
      }

      // 保存到临时目录
      final tempDir =
          await (await PlatformPaths.tempDir()).createTemp('opl_logs_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final zipPath = p.join(tempDir.path, 'opl_logs_$timestamp.zip');
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipData);

      L.i('Logs exported to: $zipPath', tag: 'log_export');
      return zipPath;
    } catch (e) {
      L.e('Failed to export logs', tag: 'log_export', error: e);
      return null;
    }
  }

  Future<void> shareLogs(String zipPath) async {
    try {
      L.i('Sharing logs: $zipPath', tag: 'log_export');
      if (PlatformSupport.isOhos) {
        final shared = await OhosShareService.shareFile(zipPath);
        if (!shared) {
          throw StateError('OHOS system sharing failed');
        }
        return;
      }
      await Share.shareXFiles(
        [XFile(zipPath)],
        subject: 'OPL 日志文件',
        text: 'OPL 应用日志导出',
      );
    } catch (e) {
      L.e('Failed to share logs', tag: 'log_export', error: e);
      rethrow;
    }
  }

  Future<void> cleanupOldExports() async {
    try {
      final tempDir = await PlatformPaths.tempDir();
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: 7));

      await for (final entity in tempDir.list()) {
        if (entity is Directory &&
            p.basename(entity.path).startsWith('opl_logs_')) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete(recursive: true);
            L.d('Cleaned up old export: ${entity.path}', tag: 'log_export');
          }
        }
      }
    } catch (e) {
      L.e('Failed to cleanup old exports', tag: 'log_export', error: e);
    }
  }

  String _redact(String text) => text.replaceAllMapped(
        RegExp(r'(token\s*[=:]\s*)\d+', caseSensitive: false),
        (match) => '${match.group(1)}[redacted]',
      );
}
