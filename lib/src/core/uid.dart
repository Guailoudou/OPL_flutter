import 'dart:math';

class Uid {
  Uid._();

  static final _hex = '0123456789abcdef'.split('');
  static final _rng = Random.secure();

  static String generate16() {
    final codeUnits = List<int>.generate(16, (_) {
      final ch = _hex[_rng.nextInt(16)];
      return ch.codeUnitAt(0);
    });
    return String.fromCharCodes(codeUnits);
  }

  static bool isValid16Hex(String? v) {
    if (v == null || v.length != 16) return false;
    for (final c in v.codeUnits) {
      final lower = (c >= 65 && c <= 90) ? (c + 32) : c;
      final isDigit = lower >= 48 && lower <= 57;
      final isHex = lower >= 97 && lower <= 102;
      if (!isDigit && !isHex) return false;
    }
    return true;
  }
}

