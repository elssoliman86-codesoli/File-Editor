import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midad/features/pdf_editor/pdf_marks.dart';
import 'package:midad/features/pdf_editor/pdf_marks_layer.dart';

Future<(PdfMarkStore, ValueNotifier<PdfEditSettings>)> _pump(
  WidgetTester tester,
  MarkTool tool,
) async {
  final store = PdfMarkStore();
  final settings = ValueNotifier(PdfEditSettings(tool: tool));
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 400,
          height: 560,
          child: PdfPageMarksLayer(
            page: 1,
            store: store,
            settings: settings,
            onTextRequest: (_, _) {},
          ),
        ),
      ),
    ),
  );
  return (store, settings);
}

void main() {
  testWidgets('the pen tool records a freehand stroke', (tester) async {
    final (store, _) = await _pump(tester, MarkTool.pen);
    final centre = tester.getCenter(find.byType(PdfPageMarksLayer));
    final gesture = await tester.startGesture(centre);
    await gesture.moveBy(const Offset(60, 0));
    await gesture.moveBy(const Offset(0, 60));
    await gesture.up();
    await tester.pump();
    expect(store.marksFor(1), hasLength(1));
    expect(store.marksFor(1).single, isA<InkMark>());
  });

  testWidgets('the rectangle tool records a shape in page units', (
    tester,
  ) async {
    final (store, _) = await _pump(tester, MarkTool.rectangle);
    final topLeft = tester.getTopLeft(find.byType(PdfPageMarksLayer));
    final gesture = await tester.startGesture(topLeft + const Offset(40, 40));
    await gesture.moveBy(const Offset(120, 80));
    await gesture.up();
    await tester.pump();
    final mark = store.marksFor(1).single as ShapeMark;
    expect(mark.from.dx, closeTo(40 / 400, 1e-6));
    expect(mark.to.dx, closeTo(160 / 400, 1e-6));
  });

  testWidgets('the hand tool never draws', (tester) async {
    final (store, _) = await _pump(tester, MarkTool.hand);
    final centre = tester.getCenter(find.byType(PdfPageMarksLayer));
    final gesture = await tester.startGesture(centre);
    await gesture.moveBy(const Offset(60, 0));
    await gesture.up();
    await tester.pump();
    expect(store.hasMarks, isFalse);
  });

  testWidgets('the eraser removes the stroke it touches', (tester) async {
    final (store, settings) = await _pump(tester, MarkTool.pen);
    final centre = tester.getCenter(find.byType(PdfPageMarksLayer));
    final draw = await tester.startGesture(centre);
    await draw.moveBy(const Offset(80, 0));
    await draw.up();
    await tester.pump();
    expect(store.marksFor(1), hasLength(1));
    settings.value = settings.value.copyWith(tool: MarkTool.eraser);
    await tester.pump();
    final erase = await tester.startGesture(centre + const Offset(40, 0));
    await erase.up();
    await tester.pump();
    expect(store.marksFor(1), isEmpty);
  });

  testWidgets('a text tap asks for text at the tapped page position', (
    tester,
  ) async {
    Offset? asked;
    final store = PdfMarkStore();
    final settings = ValueNotifier(const PdfEditSettings(tool: MarkTool.text));
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 400,
            height: 560,
            child: PdfPageMarksLayer(
              page: 3,
              store: store,
              settings: settings,
              onTextRequest: (page, position) {
                expect(page, 3);
                asked = position;
              },
            ),
          ),
        ),
      ),
    );
    final topLeft = tester.getTopLeft(find.byType(PdfPageMarksLayer));
    final gesture = await tester.startGesture(topLeft + const Offset(100, 200));
    await gesture.up();
    await tester.pump();
    expect(asked, isNotNull);
    expect(asked!.dx, closeTo(.25, 1e-6));
    expect(asked!.dy, closeTo(.5, 1e-6));
  });
}
