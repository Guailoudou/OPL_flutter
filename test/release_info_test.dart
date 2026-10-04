import 'package:flutter_test/flutter_test.dart';
import 'package:opl_config_manager/src/models/release_info.dart';

void main() {
  test('prefers the matching architecture and supports legacy release keys',
      () {
    const map = {'linux': 'legacy', 'linux-x64': 'intel', 'linux-arm64': 'arm'};
    expect(releaseForPlatform(map, 'linux', architecture: 'arm64'), 'arm');
    expect(releaseForPlatform(map, 'linux', architecture: 'x64'), 'intel');
    expect(
        releaseForPlatform({'macos': 'legacy'}, 'macos', architecture: 'arm64'),
        'legacy');
    expect(releaseForPlatform(map, 'windows', architecture: 'x64'), isNull);
  });
}
