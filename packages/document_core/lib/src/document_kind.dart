enum DocumentKind {
  docx,
  pdf,
  txt,
  markdown,
  image,
  unknown;

  static DocumentKind fromName(String name, {List<int>? header}) {
    final extension = name.toLowerCase().split('.').last;
    if (header != null && header.length >= 4) {
      if (header[0] == 0x25 &&
          header[1] == 0x50 &&
          header[2] == 0x44 &&
          header[3] == 0x46) {
        return DocumentKind.pdf;
      }
      if (header[0] == 0xFF && header[1] == 0xD8) {
        return DocumentKind.image;
      }
      if (header[0] == 0x89 && header[1] == 0x50) {
        return DocumentKind.image;
      }
    }
    return switch (extension) {
      'docx' || 'dotx' || 'docm' => DocumentKind.docx,
      'pdf' => DocumentKind.pdf,
      'md' || 'markdown' || 'mdown' => DocumentKind.markdown,
      'txt' || 'json' || 'xml' || 'html' || 'csv' || 'log' => DocumentKind.txt,
      'jpg' || 'jpeg' || 'png' || 'webp' => DocumentKind.image,
      _ => DocumentKind.unknown,
    };
  }

  /// Plain-text based kinds share the text codec and the text payload.
  bool get isTextBased => this == txt || this == markdown;

  String get defaultExtension => switch (this) {
    DocumentKind.docx => 'docx',
    DocumentKind.pdf => 'pdf',
    DocumentKind.txt => 'txt',
    DocumentKind.markdown => 'md',
    DocumentKind.image => 'png',
    DocumentKind.unknown => 'bin',
  };

  String get mimeType => switch (this) {
    DocumentKind.docx =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    DocumentKind.pdf => 'application/pdf',
    DocumentKind.txt => 'text/plain',
    DocumentKind.markdown => 'text/markdown',
    DocumentKind.image => 'image/*',
    DocumentKind.unknown => 'application/octet-stream',
  };
}
