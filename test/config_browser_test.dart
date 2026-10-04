@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:opl_config_manager/src/core/config_store.dart';
import 'package:opl_config_manager/src/core/settings_store.dart';
import 'package:opl_config_manager/src/core/text_document_store.dart';
import 'package:opl_config_manager/src/core/platform_support.dart';

void main() {
  test('browser persists configuration without native filesystem calls',
      () async {
    expect(PlatformSupport.canRunCore, isFalse);
    expect(PlatformSupport.isDesktop, isFalse);
    await TextDocumentStore('config.json').write(
        '{"network":{"Node":"1234567890abcdef","Token":18446744073709551615},"apps":[]}');
    final store = ConfigStore();
    final loaded = await store.loadOrCreate();
    expect(loaded.network.token.toString(), '18446744073709551615');
    await store.save(
        loaded.copyWith(network: loaded.network.copyWith(shareBandwidth: 77)));
    expect((await ConfigStore().loadOrCreate()).network.shareBandwidth, 77);
    await TextDocumentStore('set.json').write('{}');
    final settings = await SettingsStore().loadOrCreate();
    await SettingsStore()
        .save(settings.copyWith(apiBase: 'https://example.test'));
    expect(
        (await SettingsStore().loadOrCreate()).apiBase, 'https://example.test');
    await TextDocumentStore('config.json').write('{broken');
    await expectLater(store.loadOrCreate(), throwsFormatException);
    expect(await TextDocumentStore('config.json').read(), '{broken');
  });
}
