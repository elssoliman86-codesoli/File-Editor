import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_convert/enough_convert.dart';

import 'iso_8859_6.dart';

class DecodedText {
  const DecodedText(this.text, this.encoding, this.eol, this.hadBom);
  final String text;
  final String encoding;
  final String eol;
  final bool hadBom;
}

class TextCodec {
  const TextCodec();

  DecodedText decode(List<int> bytes, {String? requestedEncoding}) {
    final encoding = requestedEncoding ?? detectEncoding(bytes);
    final data = _stripBom(bytes, encoding);
    final String text;
    switch (encoding) {
      case 'utf-16le':
        text = _decodeUtf16(data, Endian.little);
        break;
      case 'utf-16be':
        text = _decodeUtf16(data, Endian.big);
        break;
      case 'windows-1256':
        text = const Windows1256Codec().decode(data);
        break;
      case 'iso-8859-6':
        text = const Iso88596Codec().decode(data);
        break;
      case 'windows-1252':
        text = const Windows1252Codec().decode(data);
        break;
      default:
        text = utf8.decode(data);
        break;
    }
    return DecodedText(text, encoding, detectEol(text), _hasBom(bytes));
  }

  Uint8List encode(
    String text, {
    String encoding = 'utf-8',
    String eol = '\n',
    bool bom = false,
  }) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final outputText = eol == '\n'
        ? normalized
        : normalized.replaceAll('\n', eol);
    final List<int> content;
    switch (encoding) {
      case 'utf-16le':
        content = _encodeUtf16(outputText, Endian.little);
        break;
      case 'utf-16be':
        content = _encodeUtf16(outputText, Endian.big);
        break;
      case 'windows-1256':
        content = const Windows1256Codec().encode(outputText);
        break;
      case 'iso-8859-6':
        content = const Iso88596Codec().encode(outputText);
        break;
      case 'windows-1252':
        content = const Windows1252Codec().encode(outputText);
        break;
      default:
        content = utf8.encode(outputText);
        break;
    }
    return Uint8List.fromList([...?_bom(encoding, bom), ...content]);
  }

  String detectEncoding(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return 'utf-8';
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return 'utf-16le';
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return 'utf-16be';
    }
    try {
      utf8.decode(bytes);
      return 'utf-8';
    } on FormatException {
      final arabic = bytes.where((b) => b >= 0xC0 && b <= 0xDA).length;
      return arabic > 2 ? 'windows-1256' : 'windows-1252';
    }
  }

  String detectEol(String text) {
    final crlf = '\r\n'.allMatches(text).length;
    final lf = '\n'.allMatches(text).length - crlf;
    final cr = '\r'.allMatches(text).length - crlf;
    if (crlf >= lf && crlf >= cr && crlf > 0) return '\r\n';
    if (cr > lf && cr > 0) return '\r';
    return '\n';
  }

  List<int> _stripBom(List<int> bytes, String encoding) {
    if (encoding == 'utf-8' &&
        bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return bytes.sublist(3);
    }
    if (encoding == 'utf-16le' &&
        bytes.length >= 2 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xFE) {
      return bytes.sublist(2);
    }
    if (encoding == 'utf-16be' &&
        bytes.length >= 2 &&
        bytes[0] == 0xFE &&
        bytes[1] == 0xFF) {
      return bytes.sublist(2);
    }
    return bytes;
  }

  bool _hasBom(List<int> bytes) {
    return (bytes.length >= 3 &&
            bytes[0] == 0xEF &&
            bytes[1] == 0xBB &&
            bytes[2] == 0xBF) ||
        (bytes.length >= 2 &&
            ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
                (bytes[0] == 0xFE && bytes[1] == 0xFF)));
  }

  List<int>? _bom(String encoding, bool include) {
    if (!include) return null;
    return switch (encoding) {
      'utf-8' => const [0xEF, 0xBB, 0xBF],
      'utf-16le' => const [0xFF, 0xFE],
      'utf-16be' => const [0xFE, 0xFF],
      _ => null,
    };
  }

  String _decodeUtf16(List<int> bytes, Endian endian) {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final usable = data.length - data.length % 2;
    final words = ByteData.sublistView(data, 0, usable);
    return String.fromCharCodes([
      for (var i = 0; i < usable; i += 2) words.getUint16(i, endian),
    ]);
  }

  List<int> _encodeUtf16(String text, Endian endian) {
    final output = ByteData(text.length * 2);
    for (var i = 0; i < text.length; i++) {
      output.setUint16(i * 2, text.codeUnitAt(i), endian);
    }
    return output.buffer.asUint8List();
  }
}
