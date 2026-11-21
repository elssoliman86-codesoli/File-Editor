import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';

import 'image_pdf_codec.dart';
import 'pdf_marks.dart';

/// Writes annotations into a PDF.
///
/// pdfrx can reorder, copy and combine pages but cannot add vector content to
/// an existing page, so each *edited* page is rendered, the marks are painted on
/// top with Flutter's canvas (which gives correct Arabic shaping and fonts) and
/// the result replaces that page. Pages without marks are copied untouched and
/// keep their selectable text. Edited pages become images: their text is no
/// longer selectable or searchable, which the UI says before saving.
class PdfAnnotationWriter {
  const PdfAnnotationWriter();

  /// Pixels per PDF point for edited pages (2.5 ≈ 180 dpi).
  static const _scale = 2.5;

  /// Returns the new PDF. [marks] is keyed by 1-based page number.
  /// [onProgress] receives (done, total) edited pages.
  Future<Uint8List> write({
    required String sourcePath,
    required Map<int, List<PdfMark>> marks,
    FutureOr<String?> Function()? passwordProvider,
    void Function(int done, int total)? onProgress,
  }) async {
    final edited = marks.keys.where((n) => marks[n]!.isNotEmpty).toList()
      ..sort();
    if (edited.isEmpty) {
      throw StateError('There are no annotations to save.');
    }
    PdfDocument? source;
    PdfDocument? output;
    final replacements = <int, PdfDocument>{};
    try {
      source = await PdfDocument.openFile(
        sourcePath,
        passwordProvider: passwordProvider,
      );
      final pageCount = source.pages.length;
      var done = 0;
      onProgress?.call(0, edited.length);
      for (final number in edited) {
        if (number < 1 || number > pageCount) continue;
        replacements[number] = await _flattenPage(
          source.pages[number - 1],
          marks[number]!,
        );
        onProgress?.call(++done, edited.length);
      }
      output = await PdfDocument.createNew(
        sourceName: 'midad-annotated-${DateTime.now().microsecondsSinceEpoch}',
      );
      output.pages = [
        for (var number = 1; number <= pageCount; number++)
          if (replacements[number] != null)
            replacements[number]!.pages.first
          else
            source.pages[number - 1],
      ];
      final bytes = await output.encodePdf();
      final check = await PdfDocument.openData(
        bytes,
        sourceName: 'verify-annotated',
      );
      try {
        if (check.pages.length != pageCount) {
          throw StateError('PDF page-count verification failed.');
        }
      } finally {
        await check.dispose();
      }
      return bytes;
    } finally {
      for (final document in replacements.values) {
        await document.dispose();
      }
      await output?.dispose();
      await source?.dispose();
    }
  }

  Future<PdfDocument> _flattenPage(PdfPage page, List<PdfMark> marks) async {
    final pixelWidth = (page.width * _scale).round();
    final pixelHeight = (page.height * _scale).round();
    final rendered = await page.render(
      fullWidth: pixelWidth.toDouble(),
      fullHeight: pixelHeight.toDouble(),
      backgroundColor: 0xFFFFFFFF,
    );
    if (rendered == null) {
      throw StateError('Page ${page.pageNumber} could not be rendered.');
    }
    ui.Image? background;
    ui.Image? composed;
    try {
      background = await _decodeBgra(
        rendered.pixels,
        rendered.width,
        rendered.height,
      );
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImage(
        background,
        ui.Offset.zero,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      final size = ui.Size(pixelWidth.toDouble(), pixelHeight.toDouble());
      for (final mark in marks) {
        mark.paint(canvas, size);
      }
      final picture = recorder.endRecording();
      composed = await picture.toImage(pixelWidth, pixelHeight);
      picture.dispose();
      final rgba = await composed.toByteData(format: ui.ImageByteFormat.rawRgba);
      final jpeg = await rgbaToJpeg(
        rgba!.buffer.asUint8List(),
        pixelWidth,
        pixelHeight,
      );
      return PdfDocument.createFromJpegData(
        jpeg,
        width: page.width,
        height: page.height,
        sourceName: 'midad-page-${page.pageNumber}',
      );
    } finally {
      rendered.dispose();
      background?.dispose();
      composed?.dispose();
    }
  }

  /// BGRA pixels from pdfrx to a [ui.Image] (what pdfrx's own helper does).
  Future<ui.Image> _decodeBgra(Uint8List pixels, int width, int height) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: width,
        height: height,
        pixelFormat: ui.PixelFormat.bgra8888,
      );
      final codec = await descriptor.instantiateCodec();
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
