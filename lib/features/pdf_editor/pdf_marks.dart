import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/widgets/markdown_preview.dart' show looksRtl;

/// Tools of the PDF editor. [hand] only navigates (pan and zoom).
enum MarkTool {
  hand,
  move,
  pen,
  highlighter,
  text,
  rectangle,
  ellipse,
  line,
  arrow,
  eraser,
}

/// An annotation drawn over a PDF page.
///
/// All geometry is stored in *page units*: 1.0 is the width of the page, so a
/// mark is independent of the zoom level and of the resolution it is exported
/// at. [paint] receives the pixel size of the page and scales by its width.
sealed class PdfMark {
  const PdfMark(this.color);

  final Color color;

  /// Bounding box in page units.
  Rect get bounds;

  PdfMark translated(Offset delta);

  void paint(Canvas canvas, Size size);

  /// Whether [point] (page units) touches this mark within [tolerance].
  bool hits(Offset point, double tolerance) =>
      bounds.inflate(tolerance).contains(point);
}

/// One or more freehand strokes: pen, highlighter or a drawn signature.
class InkMark extends PdfMark {
  const InkMark({
    required this.strokes,
    required Color color,
    required this.width,
    this.highlight = false,
  }) : super(color);

  final List<List<Offset>> strokes;

  /// Stroke width in page units.
  final double width;
  final bool highlight;

  @override
  Rect get bounds {
    var rect = Rect.zero;
    var first = true;
    for (final stroke in strokes) {
      for (final point in stroke) {
        final box = Rect.fromCircle(center: point, radius: width / 2);
        rect = first ? box : rect.expandToInclude(box);
        first = false;
      }
    }
    return rect;
  }

  @override
  InkMark translated(Offset delta) => InkMark(
    strokes: [
      for (final stroke in strokes) [for (final p in stroke) p + delta],
    ],
    color: color,
    width: width,
    highlight: highlight,
  );

  InkMark withStroke(List<Offset> stroke) => InkMark(
    strokes: [stroke],
    color: color,
    width: width,
    highlight: highlight,
  );

  @override
  bool hits(Offset point, double tolerance) {
    final reach = tolerance + width / 2;
    for (final stroke in strokes) {
      if (stroke.length == 1 && (stroke.first - point).distance <= reach) {
        return true;
      }
      for (var i = 1; i < stroke.length; i++) {
        if (_distanceToSegment(point, stroke[i - 1], stroke[i]) <= reach) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = highlight ? color.withValues(alpha: .38) : color
      ..style = PaintingStyle.stroke
      ..strokeCap = highlight ? StrokeCap.butt : StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width * size.width
      ..isAntiAlias = true;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first * size.width,
          width * size.width / 2,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()
        ..moveTo(stroke.first.dx * size.width, stroke.first.dy * size.width);
      for (var i = 1; i < stroke.length - 1; i++) {
        final current = stroke[i] * size.width;
        final next = stroke[i + 1] * size.width;
        // Quadratic smoothing through the midpoints keeps the line round.
        path.quadraticBezierTo(
          current.dx,
          current.dy,
          (current.dx + next.dx) / 2,
          (current.dy + next.dy) / 2,
        );
      }
      final last = stroke.last * size.width;
      path.lineTo(last.dx, last.dy);
      canvas.drawPath(path, paint);
    }
  }
}

enum ShapeKind { rectangle, ellipse, line, arrow }

class ShapeMark extends PdfMark {
  const ShapeMark({
    required this.kind,
    required this.from,
    required this.to,
    required Color color,
    required this.width,
  }) : super(color);

  final ShapeKind kind;
  final Offset from;
  final Offset to;
  final double width;

  @override
  Rect get bounds => Rect.fromPoints(from, to);

  @override
  ShapeMark translated(Offset delta) => ShapeMark(
    kind: kind,
    from: from + delta,
    to: to + delta,
    color: color,
    width: width,
  );

  ShapeMark withEnd(Offset end) =>
      ShapeMark(kind: kind, from: from, to: end, color: color, width: width);

  @override
  bool hits(Offset point, double tolerance) {
    final reach = tolerance + width / 2;
    if (kind == ShapeKind.line || kind == ShapeKind.arrow) {
      return _distanceToSegment(point, from, to) <= reach;
    }
    final rect = bounds;
    // Hollow shapes are picked by their outline, not by their empty interior.
    final outer = rect.inflate(reach);
    final inner = rect.deflate(reach);
    return outer.contains(point) &&
        (inner.width <= 0 || inner.height <= 0 || !inner.contains(point));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width * size.width
      ..isAntiAlias = true;
    final a = from * size.width;
    final b = to * size.width;
    switch (kind) {
      case ShapeKind.rectangle:
        canvas.drawRect(Rect.fromPoints(a, b), paint);
      case ShapeKind.ellipse:
        canvas.drawOval(Rect.fromPoints(a, b), paint);
      case ShapeKind.line:
        canvas.drawLine(a, b, paint);
      case ShapeKind.arrow:
        canvas.drawLine(a, b, paint);
        final delta = b - a;
        if (delta.distance < 1) return;
        final angle = math.atan2(delta.dy, delta.dx);
        final head = math.max(width * size.width * 4, size.width * .02);
        for (final side in const [-1, 1]) {
          final wing = angle + math.pi + side * math.pi / 7;
          canvas.drawLine(
            b,
            b + Offset(math.cos(wing), math.sin(wing)) * head,
            paint,
          );
        }
    }
  }
}

/// A text box. [position] is its top-left corner and [size] the font size,
/// both in page units. Arabic and other right-to-left text is shaped by
/// Flutter's text engine, so it renders correctly in the exported PDF too.
class TextMark extends PdfMark {
  TextMark({
    required this.position,
    required this.text,
    required Color color,
    required this.size,
  }) : super(color);

  final Offset position;
  final String text;
  final double size;

  /// Fixed reference width used to measure the box without a real page size.
  static const _reference = 1000.0;

  TextPainter _layout(double pageWidth) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'NotoNaskhArabic',
        fontSize: size * pageWidth,
        height: 1.35,
        color: color,
      ),
    ),
    textDirection: looksRtl(text) ? TextDirection.rtl : TextDirection.ltr,
  )..layout(maxWidth: math.max(1, (1 - position.dx) * pageWidth));

  @override
  Rect get bounds {
    final painter = _layout(_reference);
    final box = Rect.fromLTWH(
      position.dx,
      position.dy,
      painter.width / _reference,
      painter.height / _reference,
    );
    painter.dispose();
    return box;
  }

  @override
  TextMark translated(Offset delta) => TextMark(
    position: position + delta,
    text: text,
    color: color,
    size: size,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final painter = _layout(size.width);
    painter.paint(canvas, position * size.width);
    painter.dispose();
  }
}

/// Paints [marks] (page units) over a page of [size] pixels.
class MarksPainter extends CustomPainter {
  const MarksPainter(this.marks);

  final List<PdfMark> marks;

  @override
  void paint(Canvas canvas, Size size) {
    for (final mark in marks) {
      mark.paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(MarksPainter oldDelegate) =>
      !identical(oldDelegate.marks, marks);
}

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
  if (lengthSquared == 0) return (p - a).distance;
  final t = ((((p - a).dx * ab.dx + (p - a).dy * ab.dy) / lengthSquared).clamp(
    0.0,
    1.0,
  )).toDouble();
  return (p - (a + ab * t)).distance;
}

/// Marks of every page with undo/redo. Marks are immutable, so a page's list
/// is its own snapshot and history is just "the list before the change".
class PdfMarkStore extends ChangeNotifier {
  final Map<int, List<PdfMark>> _pages = {};
  final List<({int page, List<PdfMark> marks})> _undo = [];
  final List<({int page, List<PdfMark> marks})> _redo = [];

  List<PdfMark> marksFor(int page) => _pages[page] ?? const <PdfMark>[];

  bool get hasMarks => _pages.values.any((marks) => marks.isNotEmpty);
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Page numbers (1-based) that carry at least one mark, ascending.
  List<int> get editedPages =>
      _pages.entries
          .where((entry) => entry.value.isNotEmpty)
          .map((entry) => entry.key)
          .toList()
        ..sort();

  void commit(int page, List<PdfMark> next) {
    _undo.add((page: page, marks: marksFor(page)));
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
    _pages[page] = List.unmodifiable(next);
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    final step = _undo.removeLast();
    _redo.add((page: step.page, marks: marksFor(step.page)));
    _pages[step.page] = step.marks;
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    final step = _redo.removeLast();
    _undo.add((page: step.page, marks: marksFor(step.page)));
    _pages[step.page] = step.marks;
    notifyListeners();
  }

  void clear() {
    _pages.clear();
    _undo.clear();
    _redo.clear();
    notifyListeners();
  }
}
