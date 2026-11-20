import 'docx_document.dart';
import 'docx_reader.dart';
import 'docx_writer.dart';

class DocxEngine {
  const DocxEngine({
    this.reader = const DocxReader(),
    this.writer = const DocxWriter(),
  });

  final DocxReader reader;
  final DocxWriter writer;

  DocxDocument open(List<int> bytes) => reader.read(bytes);

  DocxBuildResult save(
    List<Map<String, dynamic>> operations, {
    DocxDocument? original,
  }) {
    return writer.write(operations, preservedPackage: original?.package);
  }
}
