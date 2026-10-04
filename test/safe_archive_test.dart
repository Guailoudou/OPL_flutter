import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opl_config_manager/src/services/safe_archive.dart';

void main() {
  test(
      'rejects traversal, absolute paths, links, duplicates and oversized entries',
      () {
    for (final name in ['../escape', '/escape', 'C:/escape', r'..\escape']) {
      expect(
          () => validateArchive(Archive()..addFile(ArchiveFile(name, 1, [0]))),
          throwsFormatException);
    }
    expect(
        () => validateArchive(Archive()
          ..addFile(ArchiveFile('link', 0, [])..isSymbolicLink = true)),
        throwsFormatException);
    expect(
        () => validateArchive(
            Archive()..addFile(ArchiveFile('a', maxExtractedBytes + 1, []))),
        throwsFormatException);
  });

  test('extracts ZIP and gzip TAR into a fresh directory', () async {
    final dir = await Directory.systemTemp.createTemp('opl_archive_test_');
    try {
      final archive = Archive()
        ..addFile(ArchiveFile('nested/core', 3, [1, 2, 3]));
      for (final tar in [false, true]) {
        final file = File('${dir.path}/${tar ? 'core.tar.gz' : 'core.zip'}');
        await file.writeAsBytes(tar
            ? GZipEncoder().encode(TarEncoder().encode(archive))!
            : ZipEncoder().encode(archive)!);
        final out = Directory('${dir.path}/${tar ? 'tar' : 'zip'}');
        await extractArchiveSafely(file, out);
        expect(await File('${out.path}/nested/core').readAsBytes(), [1, 2, 3]);
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('permits internal framework links and rejects links escaping staging',
      () {
    final internal = ArchiveFile('App.framework/Versions/Current', 0, [])
      ..isSymbolicLink = true
      ..nameOfLinkedFile = 'A';
    expect(
        () => validateArchive(Archive()..addFile(internal)), returnsNormally);
    for (final target in ['../../../outside', '/outside', r'C:\outside']) {
      final link = ArchiveFile('nested/link', 0, [])
        ..isSymbolicLink = true
        ..nameOfLinkedFile = target;
      expect(() => validateArchive(Archive()..addFile(link)),
          throwsFormatException);
    }
  });
}
