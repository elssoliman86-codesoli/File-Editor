import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'docx_document.dart';
import 'ooxml.dart';

class DocxReader {
  const DocxReader();

  DocxDocument read(List<int> bytes) {
    if (bytes.length > 64 * 1024 * 1024) {
      throw const FormatException('DOCX input exceeds the 64 MB limit.');
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    if (archive.length > 4096) {
      throw const FormatException('DOCX contains too many package entries.');
    }
    final package = <String, List<int>>{};
    var total = 0;
    for (final entry in archive) {
      _validateEntry(entry);
      if (!entry.isFile) continue;
      final data = entry.readBytes();
      if (data == null) continue;
      total += data.length;
      if (total > 192 * 1024 * 1024) {
        throw const FormatException('DOCX expanded content is too large.');
      }
      package[entry.name] = List<int>.from(data);
    }
    final main = package['word/document.xml'];
    if (main == null) throw const FormatException('Missing word/document.xml.');
    final source = utf8.decode(main);
    _validateXml(source);
    final root = XmlDocument.parse(source);
    final body = root.descendants.whereType<XmlElement>().firstWhere(
      (e) => e.name.local == 'body',
      orElse: () => throw const FormatException('Missing document body.'),
    );
    final operations = <Map<String, dynamic>>[];
    final warnings = <String>[];
    var listCounter = 0;
    for (final block in body.childElements) {
      if (block.name.local == 'p') {
        _readParagraph(block, operations, ++listCounter);
      } else if (block.name.local == 'tbl') {
        _readTable(block, operations);
        warnings.add('Tables are preserved but have limited visual editing.');
      } else if (block.name.local != 'sectPr') {
        warnings.add('Unsupported body element preserved: ${block.name.local}');
      }
    }
    if (operations.isEmpty || operations.last['insert'] != '\n') {
      operations.add(const {'insert': '\n'});
    }
    if (package.keys.any((name) => name.contains('vbaProject'))) {
      warnings.add('Macros are preserved as data and are never executed.');
    }
    if (package.keys.any((name) => name.contains('comments'))) {
      warnings.add('Comments and tracked changes are preserved, not edited.');
    }
    return DocxDocument(
      operations: operations,
      originalBytes: bytes,
      package: package,
      warnings: warnings.toSet().toList(),
    );
  }

  void _readParagraph(
    XmlElement paragraph,
    List<Map<String, dynamic>> operations,
    int listId,
  ) {
    final pPr = child(paragraph, 'pPr');
    final blockAttributes = <String, dynamic>{};
    final style = pPr == null
        ? null
        : attribute(child(pPr, 'pStyle') ?? _empty, 'val');
    final header = _headingLevel(style);
    if (header != null) blockAttributes['header'] = header;
    final align = pPr == null
        ? null
        : attribute(child(pPr, 'jc') ?? _empty, 'val');
    if (align != null) {
      blockAttributes['align'] = switch (align) {
        'both' => 'justify',
        'start' => null,
        'end' => 'right',
        _ => align,
      };
    }
    if (enabled(pPr == null ? null : child(pPr, 'bidi'))) {
      blockAttributes['direction'] = 'rtl';
    }
    if (child(pPr ?? _empty, 'numPr') != null) {
      blockAttributes['list'] = 'bullet';
    }
    if (enabled(pPr == null ? null : child(pPr, 'keepNext')) &&
        header == null) {
      blockAttributes['blockquote'] = true;
    }
    for (final node in paragraph.descendants.whereType<XmlElement>()) {
      switch (node.name.local) {
        case 't' || 'delText':
          final run = _ancestor(node, 'r');
          final attrs = run == null ? null : _runAttributes(run);
          final hyperlink = _ancestor(node, 'hyperlink');
          if (hyperlink != null) {
            final target =
                attribute(hyperlink, 'id') ?? attribute(hyperlink, 'anchor');
            if (target != null)
              (attrs ??= <String, dynamic>{})['link'] = target;
          }
          _insert(operations, node.innerText, attrs);
        case 'tab':
          _insert(operations, '\t', null);
        case 'br' || 'cr':
          _insert(operations, '\n', null);
        case 'drawing' || 'pict':
          _insert(operations, '[صورة محفوظة]', const {
            'italic': true,
            'color': '#A8B3CF',
          });
        case 'oMath' || 'oMathPara':
          _insert(operations, '[معادلة محفوظة]', const {'italic': true});
      }
    }
    blockAttributes.removeWhere((key, value) => value == null);
    _insert(operations, '\n', blockAttributes.isEmpty ? null : blockAttributes);
  }

  Map<String, dynamic>? _runAttributes(XmlElement run) {
    final props = child(run, 'rPr');
    if (props == null) return null;
    final attrs = <String, dynamic>{};
    if (enabled(child(props, 'b')) || enabled(child(props, 'bCs'))) {
      attrs['bold'] = true;
    }
    if (enabled(child(props, 'i')) || enabled(child(props, 'iCs'))) {
      attrs['italic'] = true;
    }
    if (enabled(child(props, 'u')) &&
        attribute(child(props, 'u')!, 'val') != 'none') {
      attrs['underline'] = true;
    }
    if (enabled(child(props, 'strike')) || enabled(child(props, 'dstrike'))) {
      attrs['strike'] = true;
    }
    final color = attribute(child(props, 'color') ?? _empty, 'val');
    if (color != null && color != 'auto') attrs['color'] = '#$color';
    final highlight = attribute(child(props, 'highlight') ?? _empty, 'val');
    if (highlight != null && highlight != 'none') {
      attrs['background'] = _highlight(highlight);
    }
    final size = attribute(
      child(props, 'szCs') ?? child(props, 'sz') ?? _empty,
      'val',
    );
    final points = int.tryParse(size ?? '');
    if (points != null) attrs['size'] = '${points / 2}';
    final fonts = child(props, 'rFonts');
    final family = fonts == null
        ? null
        : attribute(fonts, 'cs') ?? attribute(fonts, 'ascii');
    if (family != null) attrs['font'] = family;
    final vertical = attribute(child(props, 'vertAlign') ?? _empty, 'val');
    if (vertical == 'superscript' || vertical == 'subscript') {
      attrs['script'] = vertical == 'superscript' ? 'super' : 'sub';
    }
    return attrs.isEmpty ? null : attrs;
  }

  void _readTable(XmlElement table, List<Map<String, dynamic>> operations) {
    for (final row in children(table, 'tr')) {
      final cells = <String>[];
      for (final cell in children(row, 'tc')) {
        cells.add(
          cell.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local == 't')
              .map((e) => e.innerText)
              .join(),
        );
      }
      _insert(operations, cells.join('  |  '), null);
      _insert(operations, '\n', const {'blockquote': true});
    }
  }

  void _insert(
    List<Map<String, dynamic>> operations,
    String text,
    Map<String, dynamic>? attributes,
  ) {
    if (text.isEmpty) return;
    if (operations.isNotEmpty) {
      final last = operations.last;
      final oldAttributes = last['attributes'];
      if (last['insert'] is String &&
          _mapsEqual(oldAttributes, attributes) &&
          !(text == '\n' || last['insert'] == '\n')) {
        last['insert'] = '${last['insert']}$text';
        return;
      }
    }
    operations.add({
      'insert': text,
      if (attributes != null && attributes.isNotEmpty) 'attributes': attributes,
    });
  }

  bool _mapsEqual(dynamic a, dynamic b) {
    if (a == null || b == null) return a == b;
    if (a is! Map || b is! Map || a.length != b.length) return false;
    return a.entries.every((entry) => b[entry.key] == entry.value);
  }

  int? _headingLevel(String? style) {
    if (style == null) return null;
    return int.tryParse(style.replaceAll(RegExp('[^0-9]'), ''));
  }

  XmlElement? _ancestor(XmlElement node, String name) {
    var current = node.parent;
    while (current is XmlElement) {
      if (current.name.local == name) return current;
      current = current.parent;
    }
    return null;
  }

  String _highlight(String name) => switch (name) {
    'yellow' => '#FFF59D',
    'green' => '#A5D6A7',
    'cyan' => '#80DEEA',
    'magenta' => '#F48FB1',
    'red' => '#EF9A9A',
    _ => '#FFF59D',
  };

  void _validateEntry(ArchiveFile entry) {
    final normalized = entry.name.replaceAll('\\', '/');
    if (normalized.startsWith('/') ||
        normalized.split('/').contains('..') ||
        entry.isSymbolicLink) {
      throw FormatException('Unsafe DOCX package entry: ${entry.name}');
    }
    if (entry.size > 96 * 1024 * 1024) {
      throw const FormatException('A DOCX package part is too large.');
    }
  }

  void _validateXml(String source) {
    if (RegExp(r'<!DOCTYPE|<!ENTITY', caseSensitive: false).hasMatch(source)) {
      throw const FormatException(
        'DTD and external XML entities are not allowed.',
      );
    }
    var depth = 0;
    for (final match in RegExp(r'<(/?)[A-Za-z_][^>]*>').allMatches(source)) {
      if (match[1] == '/') {
        depth--;
      } else if (!match[0]!.endsWith('/>')) {
        depth++;
      }
      if (depth > 256) throw const FormatException('XML nesting is too deep.');
    }
  }

  static final _empty = XmlElement(XmlName('empty'));
}
