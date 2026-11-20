import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:document_core/document_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/platform/storage_channel.dart';

class DocumentExportService {
  DocumentExportService(this._storage);
  final StorageChannel _storage;

  Future<SaveReceipt> save({
    required String name,
    required DocumentKind kind,
    required Uint8List bytes,
  }) async {
    final receipt = await _storage.saveCopy(
      name: name,
      mimeType: kind.mimeType,
      bytes: bytes,
    );
    if (!receipt.verified || receipt.sha256.isEmpty) {
      throw const DocumentFailure(
        'The destination did not pass read-back verification.',
      );
    }
    return receipt;
  }

  Future<void> share(String name, Uint8List bytes, String mimeType) async {
    final directory = await Directory.systemTemp.createTemp('midad-share-');
    final file = await File('${directory.path}/$name')
        .writeAsBytes(bytes, flush: true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: mimeType)],
          text: name,
        ),
      );
    } finally {
      Future.delayed(const Duration(minutes: 5), () async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
    }
  }

  Future<void> printText({
    required String title,
    required String text,
    bool rtl = true,
  }) async {
    final bytes = await textToPdf(title: title, text: text, rtl: rtl);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: '$title.pdf');
  }

  Future<void> printPdf(Uint8List bytes, String title) =>
      Printing.layoutPdf(onLayout: (_) async => bytes, name: title);

  Future<Uint8List> textToPdf({
    required String title,
    required String text,
    bool rtl = true,
  }) async {
    final font = await rootBundle.load(
      'assets/fonts/NotoNaskhArabic-Variable.ttf',
    );
    return compute(
      _generateTextPdf,
      _PdfInput(
        title: title,
        text: text,
        rtl: rtl,
        fontBytes: font.buffer.asUint8List(),
      ),
    );
  }
}

Future<Uint8List> _generateTextPdf(_PdfInput input) async {
  final fontData = ByteData.view(input.fontBytes.buffer);
  final font = pw.Font.ttf(fontData);
  final bold = pw.Font.ttf(fontData);
  final document = pw.Document(
    title: input.title,
    author: 'Midad',
    creator: 'Midad',
  );
  final paragraphs = input.text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      textDirection: input.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      theme: pw.ThemeData.withFont(base: font, bold: bold),
      header: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 12),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.blueGrey200),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              input.title,
              style: pw.TextStyle(
                font: bold,
                fontSize: 11,
                color: PdfColors.blueGrey700,
              ),
            ),
            pw.Text(
              'Midad',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.blueGrey400,
              ),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        for (final paragraph in paragraphs)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 9),
            child: pw.Text(
              paragraph.isEmpty ? ' ' : paragraph,
              textDirection: input.rtl
                  ? pw.TextDirection.rtl
                  : pw.TextDirection.ltr,
              textAlign: input.rtl ? pw.TextAlign.right : pw.TextAlign.left,
              style: pw.TextStyle(font: font, fontSize: 15, height: 1.65),
            ),
          ),
      ],
    ),
  );
  return document.save();
}

class _PdfInput {
  const _PdfInput({
    required this.title,
    required this.text,
    required this.rtl,
    required this.fontBytes,
  });
  final String title;
  final String text;
  final bool rtl;
  final Uint8List fontBytes;
}

String deltaToPlainText(List<Map<String, dynamic>> operations) {
  final output = StringBuffer();
  for (final operation in operations) {
    final insert = operation['insert'];
    if (insert is String) output.write(insert);
    if (insert is Map && insert.containsKey('image')) output.write('[Image]\n');
  }
  return output.toString();
}

String operationsAsJson(List<Map<String, dynamic>> operations) =>
    jsonEncode(operations);
