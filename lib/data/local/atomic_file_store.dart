import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

class AtomicFileStore {
  const AtomicFileStore();

  /// Writes [bytes] atomically (temp file, then rename).
  ///
  /// With [verify] the temp file is read back and hashed before the swap; that
  /// is right for user-visible saves. Autosave/recovery writes pass `false`:
  /// reading back and hashing a large document on every pause froze the UI.
  Future<String> write(
    File target,
    List<int> bytes, {
    bool verify = true,
  }) async {
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    if (!verify) {
      await temp.rename(target.path);
      return '';
    }
    final check = await temp.readAsBytes();
    if (check.length != bytes.length ||
        sha256.convert(check) != sha256.convert(bytes)) {
      await temp.delete();
      throw const FileSystemException('Atomic write verification failed.');
    }
    if (await target.exists()) await target.delete();
    await temp.rename(target.path);
    return sha256.convert(check).toString();
  }

  Future<Uint8List> readVerified(String path, String expectedHash) async {
    final bytes = await File(path).readAsBytes();
    if (sha256.convert(bytes).toString() != expectedHash) {
      throw const FileSystemException('Stored document hash mismatch.');
    }
    return bytes;
  }

  String safeName(String input, String extension) {
    var name = p
        .basename(input)
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    if (name.isEmpty || name == '.' || name == '..')
      name = 'document.$extension';
    if (!name.toLowerCase().endsWith('.${extension.toLowerCase()}')) {
      name = '${p.basenameWithoutExtension(name)}.$extension';
    }
    return name.length > 120 ? '${name.substring(0, 100)}.$extension' : name;
  }
}
