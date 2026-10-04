import 'package:flutter_test/flutter_test.dart';
import 'package:opl_config_manager/src/core/config_store.dart';

void main() {
  test('preserves an unsigned token above the signed 64-bit limit', () {
    const token = '9223372036854775809';
    final config = ConfigStore.decode('''
{
  "Network": {
    "Token": $token,
    "Node": "0123456789abcdef",
    "User": "precision-test"
  },
  "Apps": [],
  "LogLevel": 1
}
''');

    expect(config.network.token.toString(), token);
    expect(config.network.user, 'precision-test');
  });
}
