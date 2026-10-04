import 'dart:io';

import 'package:path/path.dart' as p;

import 'platform_paths.dart';

/// Serializes replacements of each document, including across store instances.
class TextDocumentStore {
  TextDocumentStore(this.name, {this.fileProvider});

  final String name;
  final Future<File> Function()? fileProvider;
  static final Map<String, Future<void>> _writes = {};

  Future<File> get file async => fileProvider != null
      ? await fileProvider!()
      : File(p.join((await PlatformPaths.configDir()).path, name));

  Future<String?> read() async {
    final target = await file;
    await _writes[target.absolute.path];
    if (!await target.exists()) return null;
    return target.readAsString();
  }

  Future<void> write(String text) async {
    final target = await file;
    final key = target.absolute.path;
    final previous = _writes[key] ?? Future<void>.value();
    final operation = previous.then((_) async {
      await target.parent.create(recursive: true);
      final temporary = File('$key.tmp');
      try {
        await temporary.writeAsString(text, flush: true);
        await temporary.rename(key);
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    });
    // A failed write must reach its caller without poisoning later writes.
    final settled =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _writes[key] = settled;
    try {
      await operation;
    } finally {
      if (identical(_writes[key], settled)) _writes.remove(key);
    }
  }
}
