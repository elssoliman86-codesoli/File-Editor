import 'package:docx_engine/docx_engine.dart';
import 'package:document_core/document_core.dart';

import 'document_record.dart';

class EditorSession {
  const EditorSession({
    required this.record,
    required this.text,
    required this.operations,
    this.originalDocx,
  });

  final DocumentRecord record;
  final String text;
  final List<Map<String, dynamic>> operations;
  final DocxDocument? originalDocx;

  DocumentKind get kind => record.kind;
}
