import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:midad/features/pdf_editor/pdf_flatten_service.dart';
import 'package:midad/features/pdf_editor/pdf_marks.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('annotations are written to the edited page only', (
    tester,
  ) async {
    await pdfrxFlutterInitialize();
    final source = pw.Document();
    for (var i = 1; i <= 3; i++) {
      source.addPage(
        pw.Page(build: (_) => pw.Center(child: pw.Text('Original page $i'))),
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/midad-integration-in.pdf');
    await file.writeAsBytes(await source.save());

    final progress = <int>[];
    final bytes = await const PdfAnnotationWriter().write(
      sourcePath: file.path,
      marks: {
        2: [
          const InkMark(
            strokes: [
              [Offset(.1, .2), Offset(.5, .3), Offset(.8, .25)],
            ],
            color: Color(0xFFFF0000),
            width: .02,
          ),
          TextMark(
            position: const Offset(.1, .6),
            text: 'مرحبا Midad',
            color: const Color(0xFF0000FF),
            size: .05,
          ),
        ],
      },
      onProgress: (done, total) => progress.add(done),
    );
    expect(progress, isNotEmpty);

    final result = await PdfDocument.openData(bytes, sourceName: 'result');
    try {
      expect(result.pages, hasLength(3));
      final first = await result.pages[0].loadText();
      expect(first?.fullText ?? '', contains('Original page 1'));
      final third = await result.pages[2].loadText();
      expect(third?.fullText ?? '', contains('Original page 3'));

      // The edited page is an image now: its own text is gone, the ink is there.
      final second = await result.pages[1].loadText();
      expect(second?.fullText ?? '', isNot(contains('Original page 2')));
      final page = result.pages[1];
      final image = await page.render(
        fullWidth: page.width,
        fullHeight: page.height,
        backgroundColor: 0xFFFFFFFF,
      );
      expect(image, isNotNull);
      var red = 0;
      final pixels = image!.pixels;
      for (var i = 0; i + 3 < pixels.length; i += 4) {
        // BGRA
        if (pixels[i + 2] > 200 && pixels[i + 1] < 80 && pixels[i] < 80) red++;
      }
      image.dispose();
      expect(red, greaterThan(50), reason: 'the red ink must be painted');
    } finally {
      await result.dispose();
    }
  });
}
