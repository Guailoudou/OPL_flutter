import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:opl_config_manager/src/core/config_models.dart';
import 'package:opl_config_manager/src/core/config_store.dart';
import 'package:opl_config_manager/src/core/settings_store.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('opl_test_'));
  tearDown(() async => dir.delete(recursive: true));

  test('a malformed configuration is never overwritten', () async {
    final file = File('${dir.path}/config.json');
    await file.writeAsString('{broken');
    final store = ConfigStore(fileProvider: () async => file);
    await expectLater(store.loadOrCreate(), throwsFormatException);
    expect(await file.readAsString(), '{broken');
  });

  test('a malformed settings file is never overwritten', () async {
    final file = File('${dir.path}/set.json');
    await file.writeAsString('[]');
    final store = SettingsStore(fileProvider: () async => file);
    await expectLater(store.loadOrCreate(), throwsFormatException);
    expect(await file.readAsString(), '[]');
  });

  test('invalid token values are surfaced without rewriting the document',
      () async {
    final file = File('${dir.path}/config.json');
    final store = ConfigStore(fileProvider: () async => file);
    for (final token in [
      '"invalid"',
      '-1',
      '18446744073709551616',
      '1.5',
      '{}'
    ]) {
      final raw = '{"Network":{"Token":$token,"Node":"invalid"}}';
      await file.writeAsString(raw);
      await expectLater(store.loadOrCreate(), throwsFormatException);
      expect(await file.readAsString(), raw);
    }
  });

  test('regenerates invalid UIDs and preserves uint64 tokens across saves',
      () async {
    final file = File('${dir.path}/config.json');
    final store = ConfigStore(fileProvider: () async => file);
    final token = BigInt.parse('18446744073709551615');
    final original = ConfigRoot.defaults();
    await store.save(original.copyWith(
        network: original.network.copyWith(
      node: 'invalid',
      token: token,
    )));
    final loaded = await store.loadOrCreate();
    expect(loaded.network.node, matches(r'^[0-9a-fA-F]{16}$'));
    expect(loaded.network.token, token);
    expect(await file.readAsString(), contains('"Token": $token'));
  });

  test('concurrent saves leave a complete latest document', () async {
    final file = File('${dir.path}/config.json');
    final store = ConfigStore(fileProvider: () async => file);
    final config = ConfigRoot.defaults();
    await Future.wait(List.generate(
        20,
        (i) => store.save(config.copyWith(
              network: config.network.copyWith(shareBandwidth: i),
            ))));
    expect((await store.loadOrCreate()).network.shareBandwidth, 19);
    expect(await File('${file.path}.tmp').exists(), isFalse);
  });

  test('reads native keys without resetting network and tunnels', () {
    final config = ConfigStore.decode('''{"network": {
      "token":18446744073709551615,"node":"1234567890abcdef",
      "user":"custom","shareBandwidth":42,"serverHost":"example.test",
      "serverPort":1234,"publicIPPort":4321},"apps":[{
      "appName":"game","srcPort":1234,"peerNode":"fedcba0987654321",
      "dstPort":5678,"enabled":1}],"logLevel":2}''');
    expect(config.network.token.toString(), '18446744073709551615');
    expect(config.network.node, '1234567890abcdef');
    expect(config.network.shareBandwidth, 42);
    expect(config.network.serverHost, 'example.test');
    expect(config.apps.single.srcPort, 1234);
    expect(config.apps.single.dstPort, 5678);
    expect(config.logLevel, 2);
  });
}
