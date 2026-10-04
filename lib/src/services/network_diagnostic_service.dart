import 'dart:async';
import 'dart:io';

import '../utils/logger.dart';

enum DiagnosticStatus {
  idle,
  running,
  completed,
  failed,
}

class DiagnosticResult {
  final String name;
  final bool success;
  final String message;
  final Duration? duration;
  final Map<String, dynamic>? details;

  DiagnosticResult({
    required this.name,
    required this.success,
    required this.message,
    this.duration,
    this.details,
  });
}

class NetworkDiagnosticService {
  DiagnosticStatus _status = DiagnosticStatus.idle;
  final List<DiagnosticResult> _results = [];
  final StreamController<DiagnosticResult> _resultController =
      StreamController<DiagnosticResult>.broadcast();

  DiagnosticStatus get status => _status;
  List<DiagnosticResult> get results => List.unmodifiable(_results);
  Stream<DiagnosticResult> get resultStream => _resultController.stream;

  Future<void> runDiagnostics() async {
    _status = DiagnosticStatus.running;
    _results.clear();

    try {
      await _testDns();
      await _testHttpConnectivity();
      await _detectNatType();
      await _testLatency();
      await _testCommonPorts();

      _status = DiagnosticStatus.completed;
      L.i('network diagnostics completed', tag: 'diagnostic');
    } catch (e) {
      _status = DiagnosticStatus.failed;
      L.e('network diagnostics failed', tag: 'diagnostic', error: e);
    }
  }

  Future<void> _testDns() async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await InternetAddress.lookup('www.baidu.com');
      stopwatch.stop();

      final diagnostic = DiagnosticResult(
        name: 'DNS 解析',
        success: result.isNotEmpty,
        message: result.isNotEmpty
            ? 'DNS 解析成功 (${result.first.address})'
            : 'DNS 解析失败',
        duration: stopwatch.elapsed,
        details: {'resolved_ip': result.first.address},
      );

      _results.add(diagnostic);
      _resultController.add(diagnostic);
      L.d('DNS test: ${diagnostic.message}', tag: 'diagnostic');
    } catch (e) {
      stopwatch.stop();
      final diagnostic = DiagnosticResult(
        name: 'DNS 解析',
        success: false,
        message: 'DNS 解析失败: $e',
        duration: stopwatch.elapsed,
      );
      _results.add(diagnostic);
      _resultController.add(diagnostic);
      L.e('DNS test failed', tag: 'diagnostic', error: e);
    }
  }

  Future<void> _testHttpConnectivity() async {
    final stopwatch = Stopwatch()..start();
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final request = await client.getUrl(Uri.parse('https://www.baidu.com'));
      final response = await request.close();
      stopwatch.stop();

      final success = response.statusCode == 200;
      final diagnostic = DiagnosticResult(
        name: 'HTTP 连通性',
        success: success,
        message: success
            ? 'HTTP 连接成功 (${response.statusCode})'
            : 'HTTP 连接失败 (状态码: ${response.statusCode})',
        duration: stopwatch.elapsed,
        details: {'status_code': response.statusCode},
      );

      _results.add(diagnostic);
      _resultController.add(diagnostic);
      L.d('HTTP test: ${diagnostic.message}', tag: 'diagnostic');

      final socket = await response.detachSocket();
      socket.destroy();
      client.close();
    } catch (e) {
      stopwatch.stop();
      final diagnostic = DiagnosticResult(
        name: 'HTTP 连通性',
        success: false,
        message: 'HTTP 连接失败: $e',
        duration: stopwatch.elapsed,
      );
      _results.add(diagnostic);
      _resultController.add(diagnostic);
      L.e('HTTP test failed', tag: 'diagnostic', error: e);
    }
  }

  Future<void> _detectNatType() async {
    final stopwatch = Stopwatch()..start();
    try {
      String natType = '未知';
      String description = 'NAT 类型检测需要 STUN 服务器支持';

      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      if (interfaces.isNotEmpty) {
        final addresses = interfaces.first.addresses;
        if (addresses.isNotEmpty) {
          final ip = addresses.first.address;
          final isPrivate = _isPrivateIp(ip);

          natType = isPrivate ? 'NAT 后' : '公网';
          description =
              isPrivate ? '检测到私有 IP ($ip)，可能位于 NAT 后' : '检测到公网 IP ($ip)';
        }
      }

      stopwatch.stop();
      final diagnostic = DiagnosticResult(
        name: 'NAT 类型',
        success: true,
        message: '$natType - $description',
        duration: stopwatch.elapsed,
        details: {'nat_type': natType},
      );

      _results.add(diagnostic);
      _resultController.add(diagnostic);
      L.d('NAT detection: ${diagnostic.message}', tag: 'diagnostic');
    } catch (e) {
      stopwatch.stop();
      final diagnostic = DiagnosticResult(
        name: 'NAT 类型',
        success: false,
        message: 'NAT 类型检测失败: $e',
        duration: stopwatch.elapsed,
      );
      _results.add(diagnostic);
      _resultController.add(diagnostic);
      L.e('NAT detection failed', tag: 'diagnostic', error: e);
    }
  }

  bool _isPrivateIp(String ip) {
    final parts = ip.split('.').map(int.parse).toList();
    if (parts.length != 4) return false;
    if (parts[0] == 10) return true;
    if (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) return true;
    if (parts[0] == 192 && parts[1] == 168) return true;
    return false;
  }

  Future<void> _testLatency() async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await Process.run('ping', ['-n', '4', 'www.baidu.com']);
      stopwatch.stop();

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final avgMatch = RegExp(r'平均 = (\d+)ms').firstMatch(output);
        final minMatch = RegExp(r'最小 = (\d+)ms').firstMatch(output);
        final maxMatch = RegExp(r'最大 = (\d+)ms').firstMatch(output);

        final avg = avgMatch?.group(1) ?? '?';
        final min = minMatch?.group(1) ?? '?';
        final max = maxMatch?.group(1) ?? '?';

        final diagnostic = DiagnosticResult(
          name: '网络延迟',
          success: true,
          message: '平均延迟: ${avg}ms (最小: ${min}ms, 最大: ${max}ms)',
          duration: stopwatch.elapsed,
          details: {
            'avg_ms': avg,
            'min_ms': min,
            'max_ms': max,
          },
        );

        _results.add(diagnostic);
        _resultController.add(diagnostic);
        L.d('Latency test: ${diagnostic.message}', tag: 'diagnostic');
      } else {
        throw Exception('Ping 失败: ${result.stderr}');
      }
    } catch (e) {
      stopwatch.stop();
      final diagnostic = DiagnosticResult(
        name: '网络延迟',
        success: false,
        message: '延迟测试失败: $e',
        duration: stopwatch.elapsed,
      );
      _results.add(diagnostic);
      _resultController.add(diagnostic);
      L.e('Latency test failed', tag: 'diagnostic', error: e);
    }
  }

  Future<void> _testCommonPorts() async {
    final ports = [80, 443, 8080, 25674];
    final results = <String, bool>{};

    for (final port in ports) {
      try {
        final socket = await Socket.connect('127.0.0.1', port,
            timeout: const Duration(seconds: 1));
        await socket.close();
        results[port.toString()] = true;
      } catch (_) {
        results[port.toString()] = false;
      }
    }

    final openPorts =
        results.entries.where((e) => e.value).map((e) => e.key).toList();
    final diagnostic = DiagnosticResult(
      name: '端口检测',
      success: true,
      message: openPorts.isEmpty
          ? '未检测到开放的常用端口'
          : '检测到开放端口: ${openPorts.join(", ")}',
      details: {'ports': results},
    );

    _results.add(diagnostic);
    _resultController.add(diagnostic);
    L.d('Port test: ${diagnostic.message}', tag: 'diagnostic');
  }

  void dispose() {
    _resultController.close();
  }
}
