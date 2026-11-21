import 'package:flutter/material.dart';

import 'pdf_marks.dart';

/// Current drawing settings, shared by the toolbar and every page overlay.
class PdfEditSettings {
  const PdfEditSettings({
    this.tool = MarkTool.hand,
    this.color = const Color(0xFFE53935),
    this.width = 0.006,
  });

  final MarkTool tool;
  final Color color;

  /// Stroke width in page units (fraction of the page width).
  final double width;

  /// Tools that take over single-finger gestures, so panning must be off.
  bool get capturesTouch => tool != MarkTool.hand;

  PdfEditSettings copyWith({MarkTool? tool, Color? color, double? width}) =>
      PdfEditSettings(
        tool: tool ?? this.tool,
        color: color ?? this.color,
        width: width ?? this.width,
      );
}

/// Draws and edits the marks of one PDF page.
///
/// Pointer events come from a raw [Listener], which does not enter the gesture
/// arena, so the viewer's own pinch-zoom keeps working. A second finger cancels
/// the stroke in progress.
class PdfPageMarksLayer extends StatefulWidget {
  const PdfPageMarksLayer({
    required this.page,
    required this.store,
    required this.settings,
    required this.onTextRequest,
    super.key,
  });

  final int page;
  final PdfMarkStore store;
  final ValueNotifier<PdfEditSettings> settings;

  /// Called with a page-unit position when the text tool is tapped.
  final void Function(int page, Offset position) onTextRequest;

  @override
  State<PdfPageMarksLayer> createState() => _PdfPageMarksLayerState();
}

class _PdfPageMarksLayerState extends State<PdfPageMarksLayer> {
  final Set<int> _pointers = {};
  PdfMark? _draft;
  PdfMark? _moving;
  Offset _moveDelta = Offset.zero;
  Offset? _downAt;
  bool _moved = false;
  List<PdfMark> _drawn = const [];

  PdfEditSettings get _settings => widget.settings.value;

  Offset _toPage(Offset local, double width) => local / width;

  void _down(PointerDownEvent event, double width) {
    _pointers.add(event.pointer);
    if (_pointers.length > 1) {
      _cancel();
      return;
    }
    final point = _toPage(event.localPosition, width);
    _downAt = point;
    _moved = false;
    final settings = _settings;
    switch (settings.tool) {
      case MarkTool.hand:
      case MarkTool.text:
        break;
      case MarkTool.pen:
        _setDraft(
          InkMark(
            strokes: [
              [point],
            ],
            color: settings.color,
            width: settings.width,
          ),
        );
      case MarkTool.highlighter:
        _setDraft(
          InkMark(
            strokes: [
              [point],
            ],
            color: settings.color,
            width: settings.width * 4,
            highlight: true,
          ),
        );
      case MarkTool.rectangle:
      case MarkTool.ellipse:
      case MarkTool.line:
      case MarkTool.arrow:
        _setDraft(
          ShapeMark(
            kind: switch (settings.tool) {
              MarkTool.rectangle => ShapeKind.rectangle,
              MarkTool.ellipse => ShapeKind.ellipse,
              MarkTool.line => ShapeKind.line,
              _ => ShapeKind.arrow,
            },
            from: point,
            to: point,
            color: settings.color,
            width: settings.width,
          ),
        );
      case MarkTool.move:
        final hit = _hit(point);
        if (hit != null) {
          _moving = hit;
          _moveDelta = Offset.zero;
          setState(() {});
        }
      case MarkTool.eraser:
        _erase(point);
    }
  }

  void _move(PointerMoveEvent event, double width) {
    if (_pointers.length != 1) return;
    final point = _toPage(event.localPosition, width);
    final start = _downAt;
    if (start != null && (point - start).distance > .004) _moved = true;
    final draft = _draft;
    if (draft is InkMark) {
      final stroke = draft.strokes.first;
      if ((point - stroke.last).distance < .0015) return;
      _setDraft(draft.withStroke([...stroke, point]));
    } else if (draft is ShapeMark) {
      _setDraft(draft.withEnd(point));
    } else if (_moving != null && start != null) {
      setState(() => _moveDelta = point - start);
    } else if (_settings.tool == MarkTool.eraser) {
      _erase(point);
    }
  }

  void _up(PointerEvent event, double width) {
    _pointers.remove(event.pointer);
    if (_pointers.isNotEmpty) return;
    final point = _toPage(event.localPosition, width);
    final settings = _settings;
    final draft = _draft;
    if (draft != null) {
      final marks = widget.store.marksFor(widget.page);
      // A zero-length shape is an accidental tap, not a drawing.
      final empty = draft is ShapeMark && !_moved;
      if (!empty) widget.store.commit(widget.page, [...marks, draft]);
    } else if (_moving != null) {
      final moving = _moving!;
      final marks = widget.store.marksFor(widget.page);
      final moved = moving.translated(_moveDelta);
      if (_moveDelta.distance > .002) {
        widget.store.commit(widget.page, [
          for (final mark in marks) identical(mark, moving) ? moved : mark,
        ]);
      }
    } else if (settings.tool == MarkTool.text && !_moved) {
      widget.onTextRequest(widget.page, point);
    }
    setState(() {
      _draft = null;
      _moving = null;
      _moveDelta = Offset.zero;
      _downAt = null;
    });
  }

  void _cancel() {
    if (_draft == null && _moving == null) return;
    setState(() {
      _draft = null;
      _moving = null;
      _moveDelta = Offset.zero;
    });
  }

  void _setDraft(PdfMark mark) => setState(() => _draft = mark);

  PdfMark? _hit(Offset point) {
    final marks = widget.store.marksFor(widget.page);
    for (var i = marks.length - 1; i >= 0; i--) {
      if (marks[i].hits(point, .012)) return marks[i];
    }
    return null;
  }

  void _erase(Offset point) {
    final hit = _hit(point);
    if (hit == null) return;
    widget.store.commit(widget.page, [
      for (final mark in widget.store.marksFor(widget.page))
        if (!identical(mark, hit)) mark,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.store, widget.settings]),
      builder: (context, _) {
        final captures = _settings.capturesTouch;
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final marks = widget.store.marksFor(widget.page);
            // Rebuild the painted list only when something actually changed.
            final moving = _moving;
            final painted = <PdfMark>[
              for (final mark in marks)
                if (identical(mark, moving))
                  mark.translated(_moveDelta)
                else
                  mark,
              ?_draft,
            ];
            _drawn = painted;
            final canvas = CustomPaint(
              size: Size(width, constraints.maxHeight),
              painter: MarksPainter(_drawn),
            );
            if (!captures) return IgnorePointer(child: canvas);
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => _down(event, width),
              onPointerMove: (event) => _move(event, width),
              onPointerUp: (event) => _up(event, width),
              onPointerCancel: (event) {
                _pointers.remove(event.pointer);
                _cancel();
              },
              child: canvas,
            );
          },
        );
      },
    );
  }
}
