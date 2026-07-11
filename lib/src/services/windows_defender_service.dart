import 'dart:io';

import '../utils/logger.dart';

class WindowsDefenderService {
  static const String _appName = 'OPL';

  Future<bool> isExcluded() async {
    if (!Platform.isWindows) {
      return false;
    }

    try {
      final exePath = Platform.resolvedExecutable;
      final result = await Process.run(
        'powershell',
        [
          '-Command',
          'Get-MpPreference | Select-Object -ExpandProperty ExclusionPath | Where-Object { \$_ -eq "$exePath" }',
        ],
        runInShell: true,
      );

      final output = result.stdout.toString().trim();
      return output.isNotEmpty;
    } catch (e) {
      L.e('failed to check Windows Defender exclusion', tag: 'defender', error: e);
      return false;
    }
  }

  Future<void> addExclusion() async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows Defender exclusion is only supported on Windows');
    }

    try {
      L.i('adding Windows Defender exclusion...', tag: 'defender');

      final exePath = Platform.resolvedExecutable;
      final result = await Process.run(
        'powershell',
        [
          '-Command',
          'Add-MpPreference -ExclusionPath "$exePath"',
        ],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        final error = result.stderr.toString();
        L.e('failed to add Windows Defender exclusion: $error', tag: 'defender');
        throw Exception('添加排除项失败: $error');
      }

      L.i('Windows Defender exclusion added successfully', tag: 'defender');
    } catch (e) {
      L.e('failed to add Windows Defender exclusion', tag: 'defender', error: e);
      rethrow;
    }
  }

  Future<void> removeExclusion() async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows Defender exclusion is only supported on Windows');
    }

    try {
      L.i('removing Windows Defender exclusion...', tag: 'defender');

      final exePath = Platform.resolvedExecutable;
      final result = await Process.run(
        'powershell',
        [
          '-Command',
          'Remove-MpPreference -ExclusionPath "$exePath"',
        ],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        final error = result.stderr.toString();
        L.e('failed to remove Windows Defender exclusion: $error', tag: 'defender');
        throw Exception('移除排除项失败: $error');
      }

      L.i('Windows Defender exclusion removed successfully', tag: 'defender');
    } catch (e) {
      L.e('failed to remove Windows Defender exclusion', tag: 'defender', error: e);
      rethrow;
    }
  }

  Future<bool> hasAdminPrivileges() async {
    if (!Platform.isWindows) {
      return false;
    }

    try {
      final result = await Process.run(
        'powershell',
        [
          '-Command',
          '([Security.Principal.WindowsIdentity]::GetCurrent().Owner).IsWellKnown([Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid)',
        ],
        runInShell: true,
      );
      return result.stdout.toString().trim().toLowerCase() == 'true';
    } catch (e) {
      L.e('failed to check admin privileges', tag: 'defender', error: e);
      return false;
    }
  }
}
