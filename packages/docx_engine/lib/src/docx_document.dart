class DocxDocument {
  const DocxDocument({
    required this.operations,
    required this.originalBytes,
    required this.package,
    required this.warnings,
  });

  final List<Map<String, dynamic>> operations;
  final List<int> originalBytes;
  final Map<String, List<int>> package;
  final List<String> warnings;
}

class DocxBuildResult {
  const DocxBuildResult(this.bytes, this.warnings);
  final List<int> bytes;
  final List<String> warnings;
}
