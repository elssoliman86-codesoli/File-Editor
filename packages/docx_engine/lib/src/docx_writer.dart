import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'docx_document.dart';
import 'ooxml.dart';

class DocxWriter {
  const DocxWriter();

  DocxBuildResult write(
    List<Map<String, dynamic>> operations, {
    Map<String, List<int>>? preservedPackage,
  }) {
    final normalized = _normalize(operations);
    final hasComplexContent = normalized.any((operation) {
      final insert = operation['insert'];
      return insert is Map && insert.containsKey('table');
    });
    if (hasComplexContent) {
      throw UnsupportedError('Embedded table Delta is not supported.');
    }
    final package = preservedPackage == null
        ? _newPackage()
        : <String, List<int>>{
            for (final entry in preservedPackage.entries)
              entry.key: List<int>.from(entry.value),
          };
    final warnings = <String>[];
    if (preservedPackage != null) {
      warnings.add(
        'Edited OOXML is regenerated for supported paragraphs; unsupported parts remain in the package for compatibility review.',
      );
    }
    package['word/document.xml'] = utf8.encode(_documentXml(normalized));
    _ensureStyles(package);
    _ensureNumbering(package);
    final imageResult = _addImages(normalized, package);
    warnings.addAll(imageResult.warnings);
    package['word/document.xml'] = utf8.encode(
      _documentXml(normalized, imageNames: imageResult.names),
    );
    _updateRelationships(package, imageResult.names);
    final archive = Archive();
    for (final entry in package.entries) {
      archive.add(ArchiveFile.bytes(entry.key, entry.value));
    }
    final bytes = ZipEncoder().encode(archive);
    return DocxBuildResult(bytes, warnings);
  }

  List<Map<String, dynamic>> _normalize(List<Map<String, dynamic>> source) {
    final result = source
        .map(
          (operation) => <String, dynamic>{
            ...operation,
            if (operation['attributes'] is Map)
              'attributes': Map<String, dynamic>.from(
                operation['attributes'] as Map,
              ),
          },
        )
        .toList();
    if (result.isEmpty || result.last['insert'] != '\n') {
      result.add(const {'insert': '\n'});
    }
    return result;
  }

  String _documentXml(
    List<Map<String, dynamic>> operations, {
    Map<int, String> imageNames = const {},
  }) {
    final paragraphs = <Map<String, dynamic>>[{}];
    for (var index = 0; index < operations.length; index++) {
      final operation = operations[index];
      final insert = operation['insert'];
      final attributes = operation['attributes'] is Map
          ? Map<String, dynamic>.from(operation['attributes'] as Map)
          : <String, dynamic>{};
      if (insert is Map) {
        if (insert['image'] != null) {
          paragraphs.last['runs'] ??= <Map<String, dynamic>>[];
          (paragraphs.last['runs'] as List<Map<String, dynamic>>).add({
            'imageIndex': index,
            'attributes': attributes,
          });
        } else {
          (paragraphs.last['runs'] ??= <Map<String, dynamic>>[]).add({
            'text': insert.keys.first == 'hr'
                ? '────────────────'
                : '[محتوى مضمّن]',
            'attributes': attributes,
          });
        }
        continue;
      }
      if (insert is! String) continue;
      var start = 0;
      for (var i = 0; i <= insert.length; i++) {
        if (i < insert.length && insert[i] != '\n') continue;
        final text = insert.substring(start, i);
        if (text.isNotEmpty) {
          _addRun(paragraphs.last, text, attributes);
        }
        if (i < insert.length) {
          paragraphs.last['block'] = attributes;
          paragraphs.add(<String, dynamic>{});
        }
        start = i + 1;
      }
    }
    final body = StringBuffer();
    var listLevel = 0;
    for (final paragraph in paragraphs) {
      final block = paragraph['block'] is Map
          ? paragraph['block'] as Map<String, dynamic>
          : const <String, dynamic>{};
      final isList = block['list'] == 'bullet' || block['list'] == 'ordered';
      if (isList) listLevel++;
      body.write(
        _paragraphXml(paragraph, block, imageNames, isList ? listLevel : 0),
      );
      if (!isList) listLevel = 0;
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="$wordNamespace" '
        'xmlns:r="$relationshipNamespace" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<w:body>$body<w:sectPr>'
        '<w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" '
        'w:header="708" w:footer="708" w:gutter="0"/>'
        '<w:bidi/></w:sectPr></w:body></w:document>';
  }

  void _addRun(
    Map<String, dynamic> paragraph,
    String text,
    Map<String, dynamic> attributes,
  ) {
    final runs = paragraph['runs'] ??= <Map<String, dynamic>>[];
    (runs as List<Map<String, dynamic>>).add({
      'text': text,
      'attributes': Map<String, dynamic>.from(attributes)
        ..removeWhere((key, value) => _blockKeys.contains(key)),
    });
  }

  String _paragraphXml(
    Map<String, dynamic> paragraph,
    Map<String, dynamic> block,
    Map<int, String> imageNames,
    int listId,
  ) {
    final pPr = StringBuffer('<w:pPr>');
    final heading = block['header'];
    if (heading != null) pPr.write('<w:pStyle w:val="Heading$heading"/>');
    if (block['direction'] == 'rtl') pPr.write('<w:bidi/>');
    final align = switch (block['align']) {
      'justify' => 'both',
      'left' => 'left',
      'right' => 'right',
      'center' => 'center',
      _ => null,
    };
    if (align != null) pPr.write('<w:jc w:val="$align"/>');
    if (listId > 0) {
      final numId = block['list'] == 'ordered' ? 2 : 1;
      pPr.write(
        '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="$numId"/></w:numPr>',
      );
    }
    if (block['blockquote'] == true) {
      pPr.write(
        '<w:ind w:start="567"/><w:pBdr><w:start w:val="single" w:sz="12" '
        'w:space="8" w:color="2F7BFF"/></w:pBdr>',
      );
    }
    final indent = block['indent'];
    if (indent is num && indent > 0) {
      pPr.write('<w:ind w:start="${(indent * 360).round()}"/>');
    }
    pPr.write(
      '<w:spacing w:after="120" w:line="276" w:lineRule="auto"/></w:pPr>',
    );
    final runs = StringBuffer();
    for (final run
        in paragraph['runs'] as List<Map<String, dynamic>>? ?? const []) {
      final attrs = run['attributes'] as Map<String, dynamic>? ?? const {};
      final rPr = _runProperties(attrs, block['direction'] == 'rtl');
      final imageIndex = run['imageIndex'] as int?;
      if (imageIndex != null && imageNames.containsKey(imageIndex)) {
        runs.write(_imageRun(imageNames[imageIndex]!, rPr));
      } else {
        runs.write(
          '<w:r>$rPr<w:t xml:space="preserve">'
          '${escapeXml(run['text'] as String? ?? '')}</w:t></w:r>',
        );
      }
    }
    return '<w:p>$pPr$runs</w:p>';
  }

  String _runProperties(Map<String, dynamic> attrs, bool paragraphRtl) {
    final xml = StringBuffer('<w:rPr>');
    xml.write(
      '<w:rFonts w:ascii="Noto Naskh Arabic" w:hAnsi="Noto Naskh Arabic" '
      'w:cs="${escapeXml(attrs['font']?.toString() ?? 'Noto Naskh Arabic')}"/>',
    );
    if (attrs['bold'] == true) xml.write('<w:b/><w:bCs/>');
    if (attrs['italic'] == true) xml.write('<w:i/><w:iCs/>');
    if (attrs['underline'] == true) xml.write('<w:u w:val="single"/>');
    if (attrs['strike'] == true) xml.write('<w:strike/>');
    final color = _hexColor(attrs['color']);
    if (color != null) xml.write('<w:color w:val="$color"/>');
    final background = _hexColor(attrs['background']);
    if (background != null)
      xml.write('<w:shd w:val="clear" w:fill="$background"/>');
    final size = halfPoints(attrs['size'], 28);
    xml.write('<w:sz w:val="$size"/><w:szCs w:val="$size"/>');
    if (attrs['script'] == 'super')
      xml.write('<w:vertAlign w:val="superscript"/>');
    if (attrs['script'] == 'sub') xml.write('<w:vertAlign w:val="subscript"/>');
    if (paragraphRtl || attrs['direction'] == 'rtl') xml.write('<w:rtl/>');
    xml.write('<w:lang w:val="en-US" w:bidi="ar-EG"/></w:rPr>');
    return xml.toString();
  }

  String? _hexColor(dynamic value) {
    if (value == null) return null;
    final text = value.toString().replaceFirst('#', '');
    if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(text)) return text.toUpperCase();
    if (RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(text)) {
      return text.substring(2).toUpperCase();
    }
    return null;
  }

  String _imageRun(String name, String rPr) {
    final id = name.replaceAll(RegExp('[^0-9]'), '');
    return '<w:r>$rPr<w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="4572000" cy="3429000"/><wp:docPr id="$id" name="$name"/>'
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic><pic:nvPicPr><pic:cNvPr id="$id" name="$name"/>'
        '<pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="rId$name"/>'
        '<a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr>'
        '<a:xfrm><a:off x="0" y="0"/><a:ext cx="4572000" cy="3429000"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>';
  }

  Map<String, List<int>> _newPackage() => {
    '[Content_Types].xml': utf8.encode(_contentTypes),
    '_rels/.rels': utf8.encode(_rootRelationships),
    'docProps/core.xml': utf8.encode(_coreProperties),
    'docProps/app.xml': utf8.encode(_appProperties),
    'word/document.xml': utf8.encode(''),
  };

  void _ensureStyles(Map<String, List<int>> package) {
    if (package.containsKey('word/styles.xml')) return;
    final styles = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<w:styles xmlns:w="$wordNamespace">'
      '<w:docDefaults><w:rPrDefault><w:rPr>'
      '<w:rFonts w:ascii="Noto Naskh Arabic" w:cs="Noto Naskh Arabic"/>'
      '<w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr></w:rPrDefault></w:docDefaults>'
      '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
      '<w:name w:val="Normal"/></w:style>',
    );
    for (var level = 1; level <= 6; level++) {
      styles.write(
        '<w:style w:type="paragraph" w:styleId="Heading$level">'
        '<w:name w:val="heading $level"/><w:basedOn w:val="Normal"/>'
        '<w:next w:val="Normal"/><w:pPr><w:keepNext/>'
        '<w:spacing w:before="${360 - level * 30}" w:after="160"/></w:pPr>'
        '<w:rPr><w:b/><w:bCs/><w:sz w:val="${44 - level * 4}"/>'
        '<w:szCs w:val="${44 - level * 4}"/></w:rPr></w:style>',
      );
    }
    package['word/styles.xml'] = utf8.encode('$styles</w:styles>');
  }

  void _ensureNumbering(Map<String, List<int>> package) {
    package['word/numbering.xml'] = utf8.encode(
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<w:numbering xmlns:w="$wordNamespace">'
      '<w:abstractNum w:abstractNumId="0"><w:lvl w:ilvl="0">'
      '<w:numFmt w:val="bullet"/><w:lvlText w:val="•"/>'
      '<w:lvlJc w:val="right"/><w:pPr><w:ind w:right="720" w:hanging="360"/>'
      '</w:pPr></w:lvl></w:abstractNum>'
      '<w:abstractNum w:abstractNumId="1"><w:lvl w:ilvl="0">'
      '<w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/>'
      '<w:lvlJc w:val="right"/><w:pPr><w:ind w:right="720" w:hanging="360"/>'
      '</w:pPr></w:lvl></w:abstractNum>'
      '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>'
      '<w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num></w:numbering>',
    );
  }

  _ImageResult _addImages(
    List<Map<String, dynamic>> operations,
    Map<String, List<int>> package,
  ) {
    final names = <int, String>{};
    final warnings = <String>[];
    var id = 100;
    for (var index = 0; index < operations.length; index++) {
      final insert = operations[index]['insert'];
      if (insert is! Map || insert['image'] == null) continue;
      final data = insert['image'];
      List<int>? bytes;
      var extension = 'png';
      if (data is List<int>) {
        bytes = data;
      } else if (data is String) {
        try {
          if (data.startsWith('data:')) {
            bytes = base64Decode(data.split(',').last);
            if (data.contains('jpeg')) extension = 'jpg';
          } else {
            bytes = base64Decode(data);
          }
        } on FormatException {
          warnings.add('An external image path could not be embedded.');
        }
      }
      if (bytes == null || bytes.isEmpty || bytes.length > 20 * 1024 * 1024)
        continue;
      final name = 'image$id.$extension';
      package['word/media/$name'] = bytes;
      names[index] = name;
      id++;
    }
    return _ImageResult(names, warnings);
  }

  void _updateRelationships(
    Map<String, List<int>> package,
    Map<int, String> images,
  ) {
    final path = 'word/_rels/document.xml.rels';
    final existing = package[path];
    final relationships = <String>[
      '<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>',
      '<Relationship Id="rIdNumbering" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>',
      if (existing != null)
        ...RegExp(r'<Relationship\b[^>]+/>')
            .allMatches(utf8.decode(existing))
            .map((m) => m[0]!)
            .where(
              (xml) =>
                  !xml.contains('/styles"') && !xml.contains('/numbering"'),
            ),
      for (final name in images.values.toSet())
        '<Relationship Id="rId$name" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/$name"/>',
    ];
    package[path] = utf8.encode(
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '${relationships.join()}</Relationships>',
    );
    final contentPath = '[Content_Types].xml';
    final types = package[contentPath] == null
        ? _contentTypes
        : utf8.decode(package[contentPath]!);
    final additions = StringBuffer();
    if (!types.contains('Extension="png"')) {
      additions.write('<Default Extension="png" ContentType="image/png"/>');
    }
    if (!types.contains('Extension="jpg"')) {
      additions.write('<Default Extension="jpg" ContentType="image/jpeg"/>');
    }
    if (!types.contains('/word/numbering.xml')) {
      additions.write(
        '<Override PartName="/word/numbering.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>',
      );
    }
    package[contentPath] = utf8.encode(
      types.replaceFirst('</Types>', '$additions</Types>'),
    );
  }

  static const _blockKeys = {
    'header',
    'align',
    'direction',
    'list',
    'blockquote',
    'code-block',
    'indent',
  };
}

class _ImageResult {
  const _ImageResult(this.names, this.warnings);
  final Map<int, String> names;
  final List<String> warnings;
}

const _contentTypes =
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Default Extension="png" ContentType="image/png"/>'
    '<Default Extension="jpg" ContentType="image/jpeg"/>'
    '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
    '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>'
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
    '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
    '</Types>';

const _rootRelationships =
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
    '</Relationships>';

final _coreProperties =
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
    '<dc:title>مستند مِداد</dc:title><dc:creator>Midad</dc:creator>'
    '<dcterms:created xsi:type="dcterms:W3CDTF">${DateTime.now().toUtc().toIso8601String()}</dcterms:created>'
    '</cp:coreProperties>';

const _appProperties =
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">'
    '<Application>Midad</Application></Properties>';
