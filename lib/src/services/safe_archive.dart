import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

const maxExtractedBytes = 1024 * 1024 * 1024;

/// Validates every entry before creating any file. Call with a fresh staging dir.
void validateArchive(Archive archive) {
  var total = 0;
  final names = <String>{};
  for (final entry in archive) {
    final name = entry.name.replaceAll('\\', '/');
    if (name.contains('\u0000') ||
        name.contains(':') ||
        p.posix.isAbsolute(name) ||
        name.split('/').contains('..') ||
        name.isEmpty ||
        !names.add(p.posix.normalize(name).toLowerCase())) {
      throw const FormatException('Unsafe or duplicate archive entry');
    }
    if (entry.isSymbolicLink) {
      final link = entry.nameOfLinkedFile.replaceAll('\\', '/');
      final resolved =
          p.posix.normalize(p.posix.join(p.posix.dirname(name), link));
      if (link.isEmpty ||
          link.contains(':') ||
          link.contains('\u0000') ||
          p.posix.isAbsolute(link) ||
          resolved == '..' ||
          resolved.startsWith('../')) {
        throw const FormatException('Unsafe symbolic link');
      }
    }
    total += entry.size;
    if (entry.size < 0 || total > maxExtractedBytes || names.length > 10000) {
      throw const FormatException('Archive exceeds extraction limits');
    }
  }
}

Future<void> extractArchiveSafely(File package, Directory destination) async {
  File? tar;
  InputFileStream? input;
  try {
    Archive archive;
    final header = await package.open();
    late List<int> magic;
    try {
      magic = await header.read(2);
    } finally {
      await header.close();
    }
    if (magic.length == 2 && magic[0] == 0x1f && magic[1] == 0x8b) {
      tar = File('${package.path}.tar');
      final output = tar.openWrite();
      var count = 0;
      try {
        await for (final chunk in gzip.decoder.bind(package.openRead())) {
          count += chunk.length;
          if (count > maxExtractedBytes) {
            throw const FormatException('Archive is too large');
          }
          output.add(chunk);
        }
        await output.flush();
      } finally {
        await output.close();
      }
      input = InputFileStream(tar.path);
      archive = TarDecoder().decodeBuffer(input);
    } else {
      input = InputFileStream(package.path);
      archive = ZipDecoder().decodeBuffer(input, verify: true);
    }
    validateArchive(archive);
    await destination.create(recursive: true);
    for (final entry in archive) {
      if (entry.isSymbolicLink) continue;
      final target = p.normalize(p.join(destination.path, entry.name));
      if (!p.isWithin(destination.path, target)) {
        throw const FormatException('Unsafe archive path');
      }
      if (!entry.isFile) {
        await Directory(target).create(recursive: true);
        continue;
      }
      await File(target).parent.create(recursive: true);
      final output = OutputFileStream(target);
      try {
        entry.writeContent(output);
      } finally {
        await output.close();
      }
      if (!Platform.isWindows && entry.unixPermissions & 0x49 != 0) {
        final result = await Process.run('chmod', ['+x', target]);
        if (result.exitCode != 0) {
          throw FileSystemException('chmod failed', target);
        }
      }
    }
    // Create verified relative links only after regular files are written.
    // macOS framework bundles require these links to retain their signatures.
    for (final entry in archive.where((entry) => entry.isSymbolicLink)) {
      final link = Link(p.join(destination.path, entry.name));
      await link.parent.create(recursive: true);
      await link.create(entry.nameOfLinkedFile);
    }
  } finally {
    await input?.close();
    if (tar != null && await tar.exists()) await tar.delete();
  }
}
