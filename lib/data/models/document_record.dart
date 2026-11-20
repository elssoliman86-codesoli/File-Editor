import 'package:document_core/document_core.dart';

class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.name,
    required this.kind,
    required this.originalPath,
    required this.payloadPath,
    required this.lastOpened,
    required this.updatedAt,
    required this.favorite,
    required this.dirty,
    required this.encoding,
    required this.eol,
    this.sourceUri,
    this.lastSavedHash,
  });

  final String id;
  final String name;
  final DocumentKind kind;
  final String originalPath;
  final String payloadPath;
  final int lastOpened;
  final int updatedAt;
  final bool favorite;
  final bool dirty;
  final String encoding;
  final String eol;
  final String? sourceUri;
  final String? lastSavedHash;

  factory DocumentRecord.fromMap(Map<String, Object?> map) => DocumentRecord(
    id: map['id']! as String,
    name: map['name']! as String,
    kind: DocumentKind.values.byName(map['kind']! as String),
    originalPath: map['original_path']! as String,
    payloadPath: map['payload_path']! as String,
    lastOpened: map['last_opened']! as int,
    updatedAt: map['updated_at']! as int,
    favorite: map['favorite']! as int == 1,
    dirty: map['dirty']! as int == 1,
    encoding: map['encoding']! as String,
    eol: (map['eol']! as String)
        .replaceAll('CRLF', '\r\n')
        .replaceAll('LF', '\n')
        .replaceAll('CR', '\r'),
    sourceUri: map['source_uri'] as String?,
    lastSavedHash: map['last_saved_hash'] as String?,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'original_path': originalPath,
    'payload_path': payloadPath,
    'last_opened': lastOpened,
    'updated_at': updatedAt,
    'favorite': favorite ? 1 : 0,
    'dirty': dirty ? 1 : 0,
    'encoding': encoding,
    'eol': switch (eol) {
      '\r\n' => 'CRLF',
      '\r' => 'CR',
      _ => 'LF',
    },
    'source_uri': sourceUri,
    'last_saved_hash': lastSavedHash,
  };

  DocumentRecord copyWith({
    String? name,
    int? lastOpened,
    int? updatedAt,
    bool? favorite,
    bool? dirty,
    String? encoding,
    String? eol,
    String? lastSavedHash,
  }) => DocumentRecord(
    id: id,
    name: name ?? this.name,
    kind: kind,
    originalPath: originalPath,
    payloadPath: payloadPath,
    lastOpened: lastOpened ?? this.lastOpened,
    updatedAt: updatedAt ?? this.updatedAt,
    favorite: favorite ?? this.favorite,
    dirty: dirty ?? this.dirty,
    encoding: encoding ?? this.encoding,
    eol: eol ?? this.eol,
    sourceUri: sourceUri,
    lastSavedHash: lastSavedHash ?? this.lastSavedHash,
  );
}
