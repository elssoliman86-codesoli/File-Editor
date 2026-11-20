import 'document_kind.dart';

class DocumentSource {
  const DocumentSource({
    required this.name,
    required this.bytes,
    this.sourceUri,
  });

  final String name;
  final List<int> bytes;
  final String? sourceUri;
}

class OpenedDocument {
  const OpenedDocument({
    required this.name,
    required this.kind,
    required this.bytes,
    this.sourceUri,
    this.text,
    this.operations = const [],
    this.encoding = 'utf-8',
    this.eol = '\n',
    this.warnings = const [],
  });

  final String name;
  final DocumentKind kind;
  final List<int> bytes;
  final String? sourceUri;
  final String? text;
  final List<Map<String, dynamic>> operations;
  final String encoding;
  final String eol;
  final List<String> warnings;
}

class SaveReceipt {
  const SaveReceipt({
    required this.name,
    required this.byteCount,
    required this.sha256,
    required this.verified,
    this.destination,
  });

  final String name;
  final int byteCount;
  final String sha256;
  final bool verified;
  final String? destination;
}

class DocumentFailure implements Exception {
  const DocumentFailure(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
