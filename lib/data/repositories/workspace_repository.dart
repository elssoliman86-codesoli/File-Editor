import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:docx_engine/docx_engine.dart';
import 'package:document_core/document_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:txt_engine/txt_engine.dart';

import '../local/atomic_file_store.dart';
import '../local/document_database.dart';
import '../models/document_record.dart';
import '../models/editor_session.dart';

class WorkspaceRepository {
  WorkspaceRepository({
    DocumentDatabase? database,
    AtomicFileStore? files,
  }) : _database = database ?? DocumentDatabase(),
       _files = files ?? const AtomicFileStore();

  final DocumentDatabase _database;
  final AtomicFileStore _files;
  static const _docx = DocxEngine();
  static const _codec = TextCodec();
  Directory? _workspace;

  Future<Directory> get workspace async {
    if (_workspace != null) return _workspace!;
    final root = await getApplicationDocumentsDirectory();
    _workspace = await Directory(p.join(root.path, 'workspace')).create(recursive: true);
    return _workspace!;
  }

  Future<List<DocumentRecord>> list() async {
    final db = await _database.instance;
    final rows = await db.query('documents', orderBy: 'last_opened DESC');
    return rows.map(DocumentRecord.fromMap).toList();
  }

  Future<DocumentRecord?> byId(String id) async {
    final db = await _database.instance;
    final rows = await db.query('documents', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : DocumentRecord.fromMap(rows.first);
  }

  Future<List<DocumentRecord>> importFiles({bool multiple = false, bool imagesOnly = false}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: multiple,
      withData: true,
      type: FileType.custom,
      allowedExtensions: imagesOnly
          ? const ['jpg', 'jpeg', 'png', 'webp']
          : const ['docx', 'dotx', 'docm', 'pdf', 'txt', 'md', 'json', 'xml', 'html', 'csv', 'log', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null) return const [];
    final records = <DocumentRecord>[];
    for (final file in result.files) {
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) bytes = await File(file.path!).readAsBytes();
      if (bytes == null) continue;
      if (bytes.length > 64 * 1024 * 1024) throw const DocumentFailure('File exceeds the 64 MB import limit.');
      final kind = DocumentKind.fromName(file.name, header: bytes.take(8).toList());
      if (kind == DocumentKind.unknown) continue;
      records.add(await importBytes(file.name, bytes, sourceUri: file.identifier));
    }
    return records;
  }

  Future<DocumentRecord> importBytes(String name, List<int> bytes, {String? sourceUri}) async {
    final kind = DocumentKind.fromName(name, header: bytes.take(8).toList());
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final root = await workspace;
    final directory = await Directory(p.join(root.path, id)).create(recursive: true);
    final safeName = _files.safeName(name, kind.defaultExtension);
    final original = File(p.join(directory.path, 'original.${kind.defaultExtension}'));
    await _files.write(original, bytes);
    final payload = File(p.join(directory.path, _payloadName(kind)));
    String text = '';
    var encoding = 'utf-8';
    var eol = '\n';
    if (kind == DocumentKind.docx) {
      final doc = await compute(_openDocx, Uint8List.fromList(bytes));
      await _files.write(payload, utf8.encode(jsonEncode(doc.operations)));
    } else if (kind == DocumentKind.txt) {
      final decoded = _codec.decode(bytes);
      text = decoded.text;
      encoding = decoded.encoding;
      eol = decoded.eol;
      await _files.write(payload, utf8.encode(text));
    } else if (kind == DocumentKind.pdf || kind == DocumentKind.image) {
      await _files.write(payload, bytes);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final record = DocumentRecord(
      id: id,
      name: safeName,
      kind: kind,
      originalPath: original.path,
      payloadPath: payload.path,
      lastOpened: now,
      updatedAt: now,
      favorite: false,
      dirty: false,
      encoding: encoding,
      eol: eol,
      sourceUri: sourceUri,
      lastSavedHash: sha256.convert(bytes).toString(),
    );
    await _upsert(record);
    return record;
  }

  Future<DocumentRecord> create({
    required DocumentKind kind,
    required String name,
    String text = '',
    List<Map<String, dynamic>> operations = const [],
    bool defaultRtl = true,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final root = await workspace;
    final directory = await Directory(p.join(root.path, id)).create(recursive: true);
    final original = File(p.join(directory.path, 'original.${kind.defaultExtension}'));
    final payload = File(p.join(directory.path, _payloadName(kind)));
    List<int> bytes;
    if (kind == DocumentKind.docx) {
      final ops = operations.isEmpty
          ? <Map<String, dynamic>>[
              {'insert': '\n', 'attributes': {'direction': defaultRtl ? 'rtl' : null}..removeWhere((k, v) => v == null)},
            ]
          : operations;
      final result = _docx.save(ops);
      bytes = result.bytes;
      await _files.write(payload, utf8.encode(jsonEncode(ops)));
    } else if (kind == DocumentKind.pdf) {
      bytes = const <int>[];
    } else {
      bytes = utf8.encode(text);
      await _files.write(payload, bytes);
    }
    if (kind != DocumentKind.pdf) await _files.write(original, bytes);
    final now = DateTime.now().millisecondsSinceEpoch;
    final record = DocumentRecord(
      id: id,
      name: _files.safeName(name, kind.defaultExtension),
      kind: kind,
      originalPath: original.path,
      payloadPath: payload.path,
      lastOpened: now,
      updatedAt: now,
      favorite: false,
      dirty: true,
      encoding: 'utf-8',
      eol: '\n',
    );
    await _upsert(record);
    return record;
  }

  Future<EditorSession> loadSession(DocumentRecord record) async {
    if (record.kind == DocumentKind.docx) {
      final ops = _decodeOperations(await File(record.payloadPath).readAsString());
      DocxDocument? original;
      if (await File(record.originalPath).exists()) {
        original = await compute(_openDocx, await File(record.originalPath).readAsBytes());
      }
      await touch(record);
      return EditorSession(record: record, text: '', operations: ops, originalDocx: original);
    }
    final text = await File(record.payloadPath).readAsString();
    await touch(record);
    return EditorSession(record: record, text: text, operations: const []);
  }

  Future<void> saveRecovery(
    DocumentRecord record, {
    String? text,
    List<Map<String, dynamic>>? operations,
    String? encoding,
    String? eol,
  }) async {
    final bytes = record.kind == DocumentKind.docx
        ? utf8.encode(jsonEncode(operations ?? const []))
        : utf8.encode(text ?? '');
    await _files.write(File(record.payloadPath), bytes);
    await _upsert(record.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      dirty: true,
      encoding: encoding,
      eol: eol,
    ));
  }

  Future<Uint8List> buildDocument(
    EditorSession session, {
    String? text,
    List<Map<String, dynamic>>? operations,
    String? encoding,
    String? eol,
    bool bom = false,
  }) async {
    if (session.kind == DocumentKind.docx) {
      final result = await compute(_saveDocx, _DocxSaveInput(
        operations ?? session.operations,
        session.originalDocx?.originalBytes,
      ));
      return result;
    }
    return _codec.encode(
      text ?? session.text,
      encoding: encoding ?? session.record.encoding,
      eol: eol ?? session.record.eol,
      bom: bom,
    );
  }

  Future<void> markExported(DocumentRecord record, Uint8List bytes) async {
    await _files.write(File(record.originalPath), bytes);
    await _upsert(record.copyWith(
      dirty: false,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      lastSavedHash: sha256.convert(bytes).toString(),
    ));
  }

  Future<void> touch(DocumentRecord record) =>
      _upsert(record.copyWith(lastOpened: DateTime.now().millisecondsSinceEpoch));

  Future<void> toggleFavorite(DocumentRecord record) =>
      _upsert(record.copyWith(favorite: !record.favorite));

  Future<void> rename(DocumentRecord record, String name) =>
      _upsert(record.copyWith(name: _files.safeName(name, record.kind.defaultExtension)));

  Future<void> remove(DocumentRecord record) async {
    final db = await _database.instance;
    await db.delete('documents', where: 'id = ?', whereArgs: [record.id]);
    final directory = File(record.payloadPath).parent;
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> _upsert(DocumentRecord record) async {
    final db = await _database.instance;
    await db.insert('documents', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  String _payloadName(DocumentKind kind) => switch (kind) {
    DocumentKind.docx => 'content.delta.json',
    DocumentKind.txt => 'content.utf8.txt',
    _ => 'content.${kind.defaultExtension}',
  };
}

DocxDocument _openDocx(Uint8List bytes) => const DocxEngine().open(bytes);

Uint8List _saveDocx(_DocxSaveInput input) {
  final original = input.originalBytes == null ? null : const DocxEngine().open(input.originalBytes!);
  return Uint8List.fromList(const DocxEngine().save(input.operations, original: original).bytes);
}

class _DocxSaveInput {
  const _DocxSaveInput(this.operations, this.originalBytes);
  final List<Map<String, dynamic>> operations;
  final Uint8List? originalBytes;
}

List<Map<String, dynamic>> _decodeOperations(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! List) throw const FormatException('Invalid recovery Delta.');
  return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
}
