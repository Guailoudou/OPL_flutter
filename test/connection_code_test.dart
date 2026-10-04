import 'package:flutter_test/flutter_test.dart';
import 'package:opl_config_manager/src/core/connection_code.dart';

void main() {
  test('accepts boundary ports and rejects invalid protocol, UID, and ports',
      () {
    expect(
        ConnectionCode.parse('2:0123456789abcdef:65535:1').isSuccess, isTrue);
    for (final code in [
      '3:0123456789abcdef:80:80',
      '1:invalid:80:80',
      '1:0123456789abcdef:65536:80',
      '0123456789abcdef:0',
    ]) {
      expect(ConnectionCode.parse(code).isSuccess, isFalse, reason: code);
    }
  });
}
