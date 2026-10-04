import 'dart:io';
import 'dart:js_interop';

@JS('localStorage')
external _Storage get _storage;

extension type _Storage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

/// Browser configuration is local to the current origin and persists on reload.
class TextDocumentStore {
  TextDocumentStore(this.name, {Future<File> Function()? fileProvider});
  final String name;

  Future<String?> read() async => _storage.getItem('opl.$name');
  Future<void> write(String text) async => _storage.setItem('opl.$name', text);
}
