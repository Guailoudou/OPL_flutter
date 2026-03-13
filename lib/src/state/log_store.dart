import 'package:flutter/foundation.dart';

class LogStore extends ChangeNotifier {
  final List<String> _lines = [];

  List<String> get lines => List.unmodifiable(_lines);

  void Function(String line)? onNewLine;

  void add(String line) {
    _lines.add(line);
    onNewLine?.call(line);
    if (_lines.length > 5000) {
      _lines.removeRange(0, _lines.length - 5000);
    }
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}

