import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/config_models.dart';
import '../core/config_store.dart';
import '../core/notice_service.dart';
import '../core/settings_models.dart';
import '../core/settings_store.dart';
import '../app/navigation.dart';
import '../utils/logger.dart';
import 'core_runner.dart';
import 'log_store.dart';

class AppController extends ChangeNotifier {
  final _store = ConfigStore();
  final _settingsStore = SettingsStore();
  final LogStore _logs;
  late final CoreRunner coreRunner;

  bool booting = true;
  String? bootError;
  ConfigRoot? config;
  AppSettings settings = AppSettings.defaults();
  
  // 预加载的公告数据
  List<Notice> _cachedNotices = [];
  bool _noticesLoaded = false;

  // Expose settings store for external access
  SettingsStore get settingsStore => _settingsStore;
  
  LogStore get logs => _logs;

  AppController({LogStore? logStore}) : _logs = logStore ?? LogStore();
  
  // 暴露公告数据供页面使用
  List<Notice> get cachedNotices => _cachedNotices;
  bool get noticesLoaded => _noticesLoaded;

  Future<void> init() async {
    try {
      // Check and request admin privileges on Windows
      if (Platform.isWindows) {
        await _checkAndRequestAdmin();
      }
      
      config = await _store.loadOrCreate();
      settings = await _settingsStore.loadOrCreate();
      logs.onNewLine = _handleLogLine;
      coreRunner = CoreRunner(
        logs: logs,
        onCoreVersionChanged: _updateCoreVersion,
      );
      // 预加载公告数据
      _preloadNotices();
    } catch (e) {
      bootError = e.toString();
    } finally {
      booting = false;
      notifyListeners();
    }
  }

  Future<void> _checkAndRequestAdmin() async {
    // Check if running as admin
    if (await _isRunningAsAdmin()) {
      logs.add('[app] running with admin privileges');
      return;
    }
    
    logs.add('[app] requesting admin privileges...');
    
    try {
      // Restart with admin privileges
      final exePath = Platform.resolvedExecutable;
      final result = await Process.start(
        'powershell',
        [
          '-WindowStyle',
          'Hidden',
          '-Command',
          'Start-Process -FilePath "$exePath" -Verb RunAs',
        ],
        runInShell: true,
      );
      
      // Exit current non-admin instance
      logs.add('[app] restarting with admin privileges...');
      exit(0);
    } catch (e) {
      logs.add('[app] failed to request admin: $e');
      // Continue without admin if request fails
    }
  }

  Future<bool> _isRunningAsAdmin() async {
    try {
      final result = await Process.run(
        'powershell',
        ['-Command', '([Security.Principal.WindowsIdentity]::GetCurrent().Owner).IsWellKnown([Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid)'],
        runInShell: true,
      );
      return result.stdout.toString().trim().toLowerCase() == 'true';
    } catch (e) {
      return false;
    }
  }

  Future<void> _checkNotices() async {
    L.d('checking notices...', tag: 'app');
    
    // 确保公告数据已加载
    if (!_noticesLoaded || _cachedNotices.isEmpty) {
      L.d('notices not loaded yet, loading...', tag: 'app');
      await _preloadNotices();
    }
    
    if (_cachedNotices.isEmpty) {
      L.w('no notices available', tag: 'app');
      return;
    }

    L.d('checking ${_cachedNotices.length} cached notices', tag: 'app');
    
    final latestNotice = _cachedNotices.first;
    final lastTime = settings.lastNoticeTime;
    
    L.d('latest notice time: ${latestNotice.time}', tag: 'app');
    L.d('last stored time: $lastTime', tag: 'app');
    
    // 比较最新公告时间和存储的时间
    bool hasNew = false;
    if (lastTime == null || lastTime.isEmpty) {
      L.d('no stored time, has new notice', tag: 'app');
      hasNew = true;
    } else {
      try {
        final latestTime = DateTime.parse(latestNotice.time.replaceAll(' ', 'T'));
        final storedTime = DateTime.parse(lastTime.replaceAll(' ', 'T'));
        hasNew = latestTime.isAfter(storedTime);
        L.d('time comparison: latest=$latestTime, stored=$storedTime, hasNew=$hasNew', tag: 'app');
      } catch (_) {
        // 如果解析失败，使用字符串比较
        hasNew = latestNotice.time.compareTo(lastTime) > 0;
        L.d('string comparison: hasNew=$hasNew', tag: 'app');
      }
    }
    
    if (hasNew) {
      L.i('showing notice dialog: ${latestNotice.title}', tag: 'app');
      _showNoticeDialog(latestNotice);
      
      // 更新存储的时间为最新公告的时间
      settings = settings.copyWith(lastNoticeTime: latestNotice.time);
      await _settingsStore.save(settings);
      L.d('saved lastNoticeTime: ${latestNotice.time}', tag: 'app');
    } else {
      L.d('no new notices', tag: 'app');
    }
  }

  // 预加载公告数据
  Future<void> _preloadNotices() async {
    L.d('preloading notices...', tag: 'app');
    try {
      final service = NoticeService();
      final response = await service.fetchNotices();
      if (response != null && response.notices.isNotEmpty) {
        // 按时间排序（最新的在前）
        _cachedNotices = List<Notice>.from(response.notices)..sort((a, b) {
          try {
            final timeA = DateTime.parse(a.time.replaceAll(' ', 'T'));
            final timeB = DateTime.parse(b.time.replaceAll(' ', 'T'));
            return timeB.compareTo(timeA);
          } catch (_) {
            return b.time.compareTo(a.time);
          }
        });
        _noticesLoaded = true;
        L.d('preloaded ${_cachedNotices.length} notices', tag: 'app');
        notifyListeners(); // 通知 UI 更新
      }
    } catch (e) {
      L.e('failed to preload notices', tag: 'app', error: e);
    }
  }

  // 公开方法供页面调用
  Future<void> checkNotices() async {
    await _checkNotices();
  }
  
  // 刷新公告数据
  Future<void> refreshNotices() async {
    await _preloadNotices();
  }

  void _showNoticeDialog(Notice notice) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) {
      L.w('navigator context not ready, skipping notice dialog', tag: 'app');
      return;
    }
    
    L.d('showing notice dialog with context: $ctx', tag: 'app');
    
    // 使用 WidgetsBinding 确保在 UI 准备好后显示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        showDialog<void>(
          context: ctx,
          barrierDismissible: false, // 防止点击外部关闭
          builder: (_) => AlertDialog(
            title: Text(notice.title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notice.content),
                  const SizedBox(height: 16),
                  Text(
                    notice.time,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
        L.d('dialog shown successfully', tag: 'app');
      } catch (e) {
        L.e('failed to show dialog', tag: 'app', error: e);
      }
    });
  }

  Future<void> reloadConfig() async {
    config = await _store.loadOrCreate();
    notifyListeners();
  }

  Future<void> saveConfig(ConfigRoot root) async {
    config = root;
    notifyListeners();
    await _store.save(root);
  }

  Future<void> resetUid() async {
    final current = config;
    if (current == null) return;
    // Force regenerate by setting invalid value then saving.
    final updated = current.copyWith(
      network: current.network.copyWith(node: 'invalid'),
    );
    await _store.save(updated);
    await reloadConfig();
  }

  Future<void> updateShareBandwidth(int value) async {
    final current = config;
    if (current == null) return;
    await saveConfig(
      current.copyWith(network: current.network.copyWith(shareBandwidth: value)),
    );
  }

  Future<void> upsertTunnel(AppTunnel tunnel, {int? index}) async {
    final current = config;
    if (current == null) return;
    final apps = [...current.apps];
    if (index != null && index >= 0 && index < apps.length) {
      apps[index] = tunnel;
    } else {
      apps.add(tunnel);
    }
    await saveConfig(current.copyWith(apps: apps));
  }

  Future<void> deleteTunnel(int index) async {
    final current = config;
    if (current == null) return;
    if (index < 0 || index >= current.apps.length) return;
    final apps = [...current.apps]..removeAt(index);
    await saveConfig(current.copyWith(apps: apps));
  }

  Future<void> toggleTunnelEnabled(int index, bool enabled) async {
    final current = config;
    if (current == null) return;
    if (index < 0 || index >= current.apps.length) return;
    final apps = [...current.apps];
    final t = apps[index];
    apps[index] = t.copyWith(enabled: enabled ? 1 : 0);
    await saveConfig(current.copyWith(apps: apps));
  }

  Future<void> startCore() async {
    final current = config;
    if (current == null) return;
    await coreRunner.ensureCorePresent();
    await coreRunner.start(current);
    notifyListeners();
  }

  Future<void> stopCore() async {
    await coreRunner.stop();
    notifyListeners();
  }

  bool get coreRunning => coreRunner.isRunning;

  // === Settings (theme & core version) ===

  ThemeMode get themeMode {
    switch (settings.themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    settings = settings.copyWith(themeMode: mode);
    notifyListeners();
    await _settingsStore.save(settings);
  }

  String? get coreVersion => settings.coreVersion;

  void _updateCoreVersion(String version) {
    settings = settings.copyWith(coreVersion: version);
    _settingsStore.save(settings);
    notifyListeners();
  }

  Future<String> checkCoreVersionStatus() async {
    final latest = await coreRunner.fetchLatestRelease();
    if (latest == null) return '无法获取远程版本信息';
    final current = settings.coreVersion;
    if (current == null || current.isEmpty) {
      return '当前未安装核心。\n最新版本：${latest.version}';
    }
    if (current == latest.version) {
      return '当前已是最新版：$current';
    }
    return '当前版本：$current\n最新版本：${latest.version}';
  }

  // === Log pattern handling ===

  void _handleLogLine(String line) {
    final lower = line.toLowerCase();

    // login ok. ... node=xxxx
    if (lower.contains('login ok')) {
      final match = RegExp(r'node=([0-9a-fA-F]{16})').firstMatch(line);
      final node = match?.group(1);
      final current = config;
      if (node != null && current != null && current.network.node != node) {
        saveConfig(
          current.copyWith(
            network: current.network.copyWith(node: node),
          ),
        );
      }
    }

    // ERROR P2PNetwork login error / no such host
    if (lower.contains('error p2pnetwork login error') ||
        lower.contains('no such host')) {
      _showDialogSafely(
        title: '连接失败',
        message: '核心连接节点失败或网络异常，请检查网络与配置。',
      );
    }

    // peer offline ... <uid> offline
    if (lower.contains('offline')) {
      final match = RegExp(r'([0-9a-fA-F]{16}) offline').firstMatch(lower);
      final peer = match?.group(1);
      if (peer != null) {
        _showDialogSafely(
          title: '对端离线',
          message: '对端节点 $peer 当前不在线，将在其上线后自动重连。',
        );
      }
    }
  }

  void _showDialogSafely({required String title, required String message}) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    showDialog<void>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

