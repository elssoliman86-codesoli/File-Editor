import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:document_core/document_core.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class StorageChannel {
  const StorageChannel();
  static const _channel = MethodChannel('com.elssoliman.midad/storage');

  Future<SaveReceipt> saveCopy({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (Platform.isAndroid) {
      final temp = await File(
        p.join(Directory.systemTemp.path, 'midad-export-${DateTime.now().microsecondsSinceEpoch}'),
      ).writeAsBytes(bytes, flush: true);
      try {
        final result = await _channel.invokeMethod<Map<Object?, Object?>>('createDocument', {
          'name': name,
          'mimeType': mimeType,
          'path': temp.path,
          'sha256': sha256.convert(bytes).toString(),
        });
        if (result == null) throw const DocumentFailure('Save was cancelled.');
        return SaveReceipt(
          name: result['name']! as String,
          destination: result['uri']! as String,
          byteCount: result['bytes']! as int,
          sha256: result['sha256']! as String,
          verified: result['verified']! as bool,
        );
      } finally {
        if (await temp.exists()) await temp.delete();
      }
    }
    final file = await File(name).writeAsBytes(bytes, flush: true);
    return SaveReceipt(
      name: name,
      destination: file.path,
      byteCount: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      verified: true,
    );
  }

  Future<SaveReceipt> replaceOriginal({
    required String uri,
    required String name,
    required Uint8List bytes,
  }) async {
    if (!Platform.isAndroid) throw UnsupportedError('Original SAF replacement is Android-only.');
    final temp = await File(
      p.join(Directory.systemTemp.path, 'midad-replace-${DateTime.now().microsecondsSinceEpoch}'),
    ).writeAsBytes(bytes, flush: true);
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('replaceDocument', {
        'uri': uri,
        'name': name,
        'path': temp.path,
        'sha256': sha256.convert(bytes).toString(),
      });
      return SaveReceipt(
        name: result?['name'] as String? ?? name,
        destination: uri,
        byteCount: result?['bytes'] as int? ?? bytes.length,
        sha256: result?['sha256'] as String? ?? sha256.convert(bytes).toString(),
        verified: result?['verified'] as bool? ?? false,
      );
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<void> setSecureScreen(bool enabled) =>
      _channel.invokeMethod<void>('setSecureScreen', {'enabled': enabled});
}
