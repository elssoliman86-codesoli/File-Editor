import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:docx_engine/docx_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = DocxEngine();

  test('new DOCX round-trip keeps text, formatting, RTL and lists', () {
    final result = engine.save([
      {
        'insert': 'عنوان المستند',
        'attributes': {'bold': true, 'size': '24'},
      },
      {
        'insert': '\n',
        'attributes': {'header': 1, 'direction': 'rtl'},
      },
      {
        'insert': 'Hello ٢٠٢٦',
        'attributes': {'italic': true, 'color': '#2F7BFF'},
      },
      {
        'insert': '\n',
        'attributes': {'list': 'bullet', 'direction': 'rtl'},
      },
    ]);
    expect(result.bytes.take(2), [0x50, 0x4B]);
    final document = engine.open(result.bytes);
    final plain = document.operations.map((e) => e['insert']).join();
    expect(plain, contains('عنوان المستند'));
    expect(plain, contains('Hello ٢٠٢٦'));
    expect(
      document.operations.any((e) => (e['attributes'] as Map?)?['header'] == 1),
      isTrue,
    );
    expect(
      document.operations.any(
        (e) => (e['attributes'] as Map?)?['direction'] == 'rtl',
      ),
      isTrue,
    );
    final xml = utf8.decode(
      ZipDecoder()
          .decodeBytes(result.bytes)
          .firstWhere((e) => e.name == 'word/document.xml')
          .content,
    );
    expect(xml, contains('<w:bidi/>'));
    expect(xml, contains('w:szCs'));
  });

  test('preserves unrelated OOXML package parts', () {
    final first = engine.save(const [
      {'insert': 'نص أول'},
    ]);
    final archive = ZipDecoder().decodeBytes(first.bytes);
    archive.add(
      ArchiveFile.string(
        'customXml/item1.xml',
        '<root><keep value="1"/></root>',
      ),
    );
    final modified = ZipEncoder().encode(archive);
    final original = engine.open(modified);
    final second = engine.save(const [
      {'insert': 'نص معدل'},
    ], original: original);
    final parts = ZipDecoder().decodeBytes(second.bytes);
    expect(parts.any((e) => e.name == 'customXml/item1.xml'), isTrue);
    expect(parts.any((e) => e.name == 'word/styles.xml'), isTrue);
  });

  test('rejects DTD and Zip Slip', () {
    final valid = engine.save(const [
      {'insert': 'safe'},
    ]);
    final archive = ZipDecoder().decodeBytes(valid.bytes);
    archive.add(ArchiveFile.string('../outside.xml', '<bad/>'));
    expect(
      () => engine.open(ZipEncoder().encode(archive)),
      throwsFormatException,
    );

    final malicious = ZipDecoder().decodeBytes(valid.bytes);
    for (final entry in malicious) {
      if (entry.name == 'word/document.xml') {
        entry.clear();
        malicious.add(
          ArchiveFile.string(
            'word/document.xml',
            '<!DOCTYPE x [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body/></w:document>',
          ),
        );
      }
    }
    expect(
      () => engine.open(ZipEncoder().encode(malicious)),
      throwsA(anything),
    );
  });

  test('page ranges validate bounds and deduplicate pages', () {
    expect(parsePageRanges('1-3,7,9-10,1', 12), [1, 2, 3, 7, 9, 10]);
    expect(() => parsePageRanges('0', 12), throwsRangeError);
    expect(() => parsePageRanges('3-1', 12), throwsRangeError);
    expect(() => parsePageRanges('13', 12), throwsRangeError);
    expect(() => parsePageRanges('a', 12), throwsFormatException);
  });
}
