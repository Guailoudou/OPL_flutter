import '../core/platform_support.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../core/config_models.dart';
import '../core/config_store.dart';
import '../core/notice_service.dart';
import '../core/settings_models.dart';
import '../core/settings_store.dart';
import '../core/ohos_core_service.dart';
import '../core/platform_paths.dart';
import '../core/url_config.dart';
import '../core/uid.dart';
import '../core/easytier_service.dart';
import '../app/navigation.dart';
import '../utils/logger.dart';
import '../services/autostart_service.dart';
import '../services/update_service.dart';
import 'core_runner.dart';
import 'log_store.dart';

class AppController extends ChangeNotifier {
  final _store = ConfigStore();
  final _settingsStore = SettingsStore();
  final LogStore _logs;
  late final CoreRunner coreRunner = CoreRunner(
    logs: logs,
    onCoreVersionChanged: _updateCoreVersion,
    onStateChanged: notifyListeners,
  );
  final UpdateService updateService;
  final autoStartService = AutoStartService();
  final easyTierService = EasyTierService();
  bool _disposed = false;
  Future<void> _settingsChanges = Future<void>.value();

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _logs.onNewLine = null;
    coreRunner.dispose();
    easyTierService.dispose();
    updateService.dispose();
    super.dispose();
  }

  bool booting = true;
  bool ohosBackgroundKeepAlive = true;
  bool ohosPictureInPicture = false;

  Future<void> setOhosKeepAlive(bool enabled,
      {bool pictureInPicture = false}) async {
    final available = await OhosCoreService.setKeepAlive(enabled,
        pictureInPicture: pictureInPicture);
    if (!available) throw StateError('系统未允许此保活方式，请检查授权和设备支持');
    if (pictureInPicture) {
      ohosPictureInPicture = enabled;
    } else {
      ohosBackgroundKeepAlive = enabled;
    }
    notifyListeners();
  }

  String? bootError;
  ConfigRoot? config;
  AppSettings settings = AppSettings.defaults();

  // 预加载的公告数据
  List<Notice> _cachedNotices = [];
  bool _noticesLoaded = false;

  // Expose settings store for external access
  SettingsStore get settingsStore => _settingsStore;

  LogStore get logs => _logs;

  AppController({LogStore? logStore})
      : _logs = logStore ?? LogStore(),
        updateService = UpdateService();

  // 暴露公告数据供页面使用
  List<Notice> get cachedNotices => _cachedNotices;
  bool get noticesLoaded => _noticesLoaded;

  Future<void> init() async {
    var initialized = false;
    try {
      config = await _store.loadOrCreate();
      settings = await _settingsStore.loadOrCreate();
      // Migrate the old desktop default. On Android, localhost points to the
      // phone itself and makes the configured backend unreachable.
      if (settings.apiBase == 'http://localhost:3000') {
        settings = settings.copyWith(apiBase: UrlConfig.defaultApiBase);
        await _settingsStore.save(settings);
      }
      // 初始化 URL 配置
      UrlConfig.setApiBase(settings.apiBase);
      UrlConfig.setUseGitee(settings.useGiteeMirror);
      if (PlatformSupport.isOhos) {
        final options = await OhosCoreService.getKeepAliveOptions();
        ohosBackgroundKeepAlive = options['continuousTask'] == true;
        ohosPictureInPicture = options['pictureInPicture'] == true;
      }
      logs.onNewLine = _handleLogLine;
      await coreRunner.initialize();
      easyTierService.onVersionChanged = _updateEasyTierVersion;

      // 初始化 UpdateService 回调
      updateService
        ..beforeInstall = (component) async {
          if (component == UpdateComponent.core && coreRunning) {
            await stopCore();
          }
          if (component == UpdateComponent.easytier &&
              easyTierService.isRunning) {
            await easyTierService.stop();
          }
        }
        ..onCoreVersionChanged = _updateCoreVersion
        ..onEasytierVersionChanged = _updateEasyTierVersion;
      await updateService.detectInstalledVersions();
      initialized = true;
      // 运营商检测已移除，不再在启动时自动检测
    } catch (e) {
      bootError = e.toString();
    } finally {
      booting = false;
      notifyListeners();
    }

    // 网络任务不应让应用一直停留在启动页。本地初始化完成后，
    // 先渲染主界面，再让更新检查和公告预加载在后台继续执行。
    if (initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(updateService.checkAllUpdates());
        unawaited(_preloadNotices());
      });
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
        final latestTime =
            DateTime.parse(latestNotice.time.replaceAll(' ', 'T'));
        final storedTime = DateTime.parse(lastTime.replaceAll(' ', 'T'));
        hasNew = latestTime.isAfter(storedTime);
        L.d('time comparison: latest=$latestTime, stored=$storedTime, hasNew=$hasNew',
            tag: 'app');
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
      await _changeSettings(
          (value) => value.copyWith(lastNoticeTime: latestNotice.time));
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
        _cachedNotices = List<Notice>.from(response.notices)
          ..sort((a, b) {
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
    await _store.save(root);
    config = root;
    notifyListeners();
  }

  Future<void> resetUid() async {
    final current = config;
    if (current == null) return;
    final updated = current.copyWith(
      network: current.network.copyWith(node: Uid.generate16()),
    );
    await saveConfig(updated);
  }

  Future<void> resetApp(BuildContext context) async {
    await stopCore();
    if (easyTierService.isRunning) await easyTierService.stop();
    if (PlatformSupport.isDesktop) {
      final dir = await PlatformPaths.configDir();
      for (final name in ['openp2p-opl.exe', 'openp2p-opl']) {
        final file = File(p.join(dir.path, name));
        if (await file.exists()) await file.delete();
      }
    }
    await _store.save(ConfigRoot.defaults());
    await updateSettings(AppSettings.defaults());
    await reloadConfig();
  }

  Future<void> updateShareBandwidth(int value) async {
    final current = config;
    if (current == null) return;
    await saveConfig(
      current.copyWith(
          network: current.network.copyWith(shareBandwidth: value)),
    );
  }

  Future<void> updateToken(BigInt value) async {
    final current = config;
    if (current == null) return;
    await saveConfig(
      current.copyWith(network: current.network.copyWith(token: value)),
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
    if (!PlatformSupport.canRunCore) {
      throw UnsupportedError('Core execution is unavailable on this platform');
    }
    final current = config;
    if (current == null) return;
    // Reset login status before starting
    if (_coreLoggedIn) {
      _coreLoggedIn = false;
    }
    _logs.add('[core] starting new session');
    await coreRunner.start(current);
    notifyListeners();
  }

  Future<void> stopCore() async {
    await coreRunner.stop();
    // Reset login status
    if (_coreLoggedIn) {
      _coreLoggedIn = false;
    }
    _logs.add('[core] stopped');
    notifyListeners();
  }

  bool get coreRunning => PlatformSupport.canRunCore && coreRunner.isRunning;

  // Core login status
  bool _coreLoggedIn = false;
  bool get coreLoggedIn => _coreLoggedIn;

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
    await _changeSettings((value) => value.copyWith(themeMode: mode));
  }

  Future<void> updateSettings(AppSettings value) =>
      _changeSettings((_) => value);

  Future<void> _changeSettings(AppSettings Function(AppSettings) change) {
    final operation = _settingsChanges.then((_) async {
      final value = change(settings);
      await _settingsStore.save(value);
      settings = value;
      UrlConfig.setApiBase(value.apiBase);
      UrlConfig.setUseGitee(value.useGiteeMirror);
      notifyListeners();
    });
    _settingsChanges =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  Future<void> setUseGiteeMirror(bool value) async {
    await _changeSettings((current) => current.copyWith(useGiteeMirror: value));
  }

  String? get coreVersion => settings.coreVersion;
  String? get easytierVersion => settings.easytierVersion;

  void _updateCoreVersion(String version) {
    unawaited(_changeSettings((value) => value.copyWith(coreVersion: version))
        .catchError((Object error) {
      logs.add('[settings] Failed to save core version: $error');
    }));
  }

  void _updateEasyTierVersion(String version) {
    unawaited(
        _changeSettings((value) => value.copyWith(easytierVersion: version))
            .catchError((Object error) {
      logs.add('[settings] Failed to save EasyTier version: $error');
    }));
  }

  // === Log pattern handling ===

  void _handleLogLine(String line) {
    final lower = line.toLowerCase();

    // login ok. ... node=xxxx
    if (lower.contains('login ok')) {
      final match = RegExp(r'node=([^\s]+)').firstMatch(line);
      final node = match?.group(1);
      final current = config;
      if (Uid.isValid16Hex(node) &&
          node != '0000000000000000' &&
          current != null &&
          current.network.node != node) {
        unawaited(saveConfig(
          current.copyWith(
            network: current.network.copyWith(node: node),
          ),
        ).catchError((Object error) {
          logs.add('[config] Failed to save the core node: $error');
        }));
      }
      // Set login status to true
      if (!_coreLoggedIn) {
        _coreLoggedIn = true;
        notifyListeners();
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
      final match = RegExp(r'([^\s]+) offline').firstMatch(lower);
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
