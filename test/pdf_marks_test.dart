import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midad/features/documents/document_actions.dart';
import 'package:midad/features/pdf_editor/pdf_marks.dart';
import 'package:midad/shared/widgets/markdown_preview.dart';

void main() {
  group('PdfMarkStore', () {
    test('commit, undo and redo restore the previous page state', () {
      final store = PdfMarkStore();
      const ink = InkMark(
        strokes: [
          [Offset(.1, .1), Offset(.2, .2)],
        ],
        color: Colors.red,
        width: .005,
      );
      expect(store.hasMarks, isFalse);
      store.commit(2, [ink]);
      expect(store.hasMarks, isTrue);
      expect(store.editedPages, [2]);
      store.undo();
      expect(store.marksFor(2), isEmpty);
      expect(store.canRedo, isTrue);
      store.redo();
      expect(store.marksFor(2), hasLength(1));
    });
  });

  group('marks geometry', () {
    test('an ink stroke is hit near its line and not far from it', () {
      const ink = InkMark(
        strokes: [
          [Offset(.1, .1), Offset(.5, .1)],
        ],
        color: Colors.black,
        width: .004,
      );
      expect(ink.hits(const Offset(.3, .105), .01), isTrue);
      expect(ink.hits(const Offset(.3, .4), .01), isFalse);
    });

    test('translating a shape moves both corners', () {
      const shape = ShapeMark(
        kind: ShapeKind.rectangle,
        from: Offset(.1, .1),
        to: Offset(.3, .2),
        color: Colors.blue,
        width: .004,
      );
      final moved = shape.translated(const Offset(.1, .2));
      expect(moved.from.dx, closeTo(.2, 1e-9));
      expect(moved.from.dy, closeTo(.3, 1e-9));
      expect(moved.bounds.width, closeTo(.2, 1e-9));
    });
  });

  group('helpers', () {
    test('looksRtl detects Arabic and Latin text', () {
      expect(looksRtl('مرحبا بالعالم'), isTrue);
      expect(looksRtl('Hello world'), isFalse);
    });
  });

  test('uniqueDocumentName numbers duplicates like Office', () {
    expect(uniqueDocumentName(const [], 'Doc', 'docx'), 'Doc.docx');
  });
}
