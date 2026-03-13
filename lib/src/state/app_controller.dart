import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/config_models.dart';
import '../core/config_store.dart';
import '../core/settings_models.dart';
import '../core/settings_store.dart';
import '../app/navigation.dart';
import 'core_runner.dart';
import 'log_store.dart';

class AppController extends ChangeNotifier {
  final _store = ConfigStore();
  final _settingsStore = SettingsStore();
  final logs = LogStore();
  late final CoreRunner coreRunner;

  bool booting = true;
  String? bootError;
  ConfigRoot? config;
  AppSettings settings = AppSettings.defaults();

  Future<void> init() async {
    try {
      config = await _store.loadOrCreate();
      settings = await _settingsStore.loadOrCreate();
      logs.onNewLine = _handleLogLine;
      coreRunner = CoreRunner(
        logs: logs,
        onCoreVersionChanged: _updateCoreVersion,
      );
    } catch (e) {
      bootError = e.toString();
    } finally {
      booting = false;
      notifyListeners();
    }
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

