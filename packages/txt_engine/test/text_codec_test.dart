import 'package:test/test.dart';
import 'package:txt_engine/txt_engine.dart';

void main() {
  const codec = TextCodec();
  const arabic = 'السَّلَامُ عَلَيْكُمْ — Midad ٢٠٢٦';

  for (final encoding in ['utf-8', 'utf-16le', 'utf-16be', 'windows-1256']) {
    test('round-trip $encoding with BOM and CRLF', () {
      // The sample must contain a line break, otherwise there is no line
      // ending to convert to CRLF and nothing for EOL detection to find.
      final sample = encoding == 'windows-1256'
          ? 'السلام عليكم - Midad 2026\nالسطر الثاني'
          : '$arabic\nالسطر الثاني';
      final bytes = codec.encode(
        sample,
        encoding: encoding,
        bom: true,
        eol: '\r\n',
      );
      final decoded = codec.decode(bytes);
      expect(decoded.encoding, encoding);
      // Single-byte code pages such as windows-1256 have no byte-order mark.
      expect(decoded.hadBom, encoding != 'windows-1256');
      expect(decoded.eol, '\r\n');
      // decode keeps the original line endings; compare modulo CRLF.
      expect(decoded.text.replaceAll('\r\n', '\n'), sample);
    });
  }

  test('UTF-16 big endian survives Arabic text', () {
    final bytes = codec.encode('أ ب ت 123', encoding: 'utf-16be');
    expect(bytes.take(2), [0x06, 0x23]);
    expect(
      codec.decode(bytes, requestedEncoding: 'utf-16be').text,
      'أ ب ت 123',
    );
  });

  test('ISO-8859-6 round-trip and invalid character handling', () {
    const sample = 'العربية English 123';
    final encoded = codec.encode(sample, encoding: 'iso-8859-6');
    // ISO-8859-6 and windows-1256 overlap, so auto-detection cannot tell them
    // apart; the user (or caller) selects ISO-8859-6 explicitly.
    expect(codec.decode(encoded, requestedEncoding: 'iso-8859-6').text, sample);
    expect(
      () => codec.encode('٢٠٢٦', encoding: 'iso-8859-6'),
      throwsFormatException,
    );
  });

  test('UTF-8 without BOM preserves the first three bytes', () {
    const sample = 'ABC بداية عربية';
    final bytes = codec.encode(sample);
    final decoded = codec.decode(bytes);
    expect(decoded.hadBom, isFalse);
    expect(decoded.text, sample);
  });

  test('UTF-16 without BOM preserves the first code unit', () {
    const sample = 'أ ب ت';
    for (final encoding in ['utf-16le', 'utf-16be']) {
      final bytes = codec.encode(sample, encoding: encoding);
      final decoded = codec.decode(bytes, requestedEncoding: encoding);
      expect(decoded.hadBom, isFalse);
      expect(decoded.text, sample);
    }
  });

  test('detects EOL style', () {
    expect(codec.detectEol('one\r\ntwo\r\n'), '\r\n');
    expect(codec.detectEol('one\ntwo\n'), '\n');
    expect(codec.detectEol('one\rtwo\r'), '\r');
  });

  test('statistics count Arabic words and lines', () {
    final stats = TextStatistics.from('كلمة أولى وكلمة ثانية\nسطر جديد');
    expect(stats.words, 6);
    expect(stats.lines, 2);
    expect(stats.characters, greaterThan(20));
  });
}
