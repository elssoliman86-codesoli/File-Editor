import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'pdf_marks.dart';
import 'pdf_marks_layer.dart';

/// Bottom toolbar of the PDF editor: tools, colours and stroke width.
class PdfEditToolbar extends StatelessWidget {
  const PdfEditToolbar({
    required this.settings,
    required this.onSignature,
    super.key,
  });

  final ValueNotifier<PdfEditSettings> settings;
  final VoidCallback onSignature;

  static const _colors = <Color>[
    Color(0xFF111111),
    Color(0xFFE53935),
    Color(0xFF1E6BFF),
    Color(0xFF16A34A),
    Color(0xFFFFD600),
    Color(0xFFFF8F00),
    Color(0xFF8E24AA),
  ];

  static const _widths = <double>[0.003, 0.006, 0.012];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 10,
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder<PdfEditSettings>(
          valueListenable: settings,
          builder: (context, value, _) {
            Widget tool(MarkTool tool, IconData icon, String key) {
              final selected = value.tool == tool;
              return IconButton(
                tooltip: l10n.t(key),
                isSelected: selected,
                style: selected
                    ? IconButton.styleFrom(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                      )
                    : null,
                onPressed: () => settings.value = value.copyWith(tool: tool),
                icon: Icon(icon),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      tool(
                        MarkTool.hand,
                        Icons.pan_tool_alt_outlined,
                        'toolHand',
                      ),
                      tool(MarkTool.move, Icons.open_with_rounded, 'toolMove'),
                      tool(MarkTool.pen, Icons.edit_rounded, 'toolPen'),
                      tool(
                        MarkTool.highlighter,
                        Icons.highlight_rounded,
                        'toolHighlighter',
                      ),
                      tool(
                        MarkTool.text,
                        Icons.text_fields_rounded,
                        'toolText',
                      ),
                      tool(
                        MarkTool.rectangle,
                        Icons.crop_square_rounded,
                        'toolRectangle',
                      ),
                      tool(
                        MarkTool.ellipse,
                        Icons.circle_outlined,
                        'toolEllipse',
                      ),
                      tool(
                        MarkTool.line,
                        Icons.horizontal_rule_rounded,
                        'toolLine',
                      ),
                      tool(
                        MarkTool.arrow,
                        Icons.arrow_right_alt_rounded,
                        'toolArrow',
                      ),
                      tool(
                        MarkTool.eraser,
                        Icons.cleaning_services_outlined,
                        'toolEraser',
                      ),
                      IconButton(
                        tooltip: l10n.t('toolSignature'),
                        onPressed: onSignature,
                        icon: const Icon(Icons.draw_outlined),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final color in _colors)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 9,
                          ),
                          child: InkResponse(
                            onTap: () =>
                                settings.value = value.copyWith(color: color),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: value.color == color
                                      ? scheme.primary
                                      : scheme.outlineVariant,
                                  width: value.color == color ? 3 : 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      for (final width in _widths)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Container(
                              width: 22,
                              height: width * 1400,
                              decoration: BoxDecoration(
                                color: scheme.onSurface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            selected: value.width == width,
                            onSelected: (_) =>
                                settings.value = value.copyWith(width: width),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Asks for the text of a new text mark. Returns null when cancelled.
Future<({String text, double size})?> showTextMarkDialog(
  BuildContext context,
) async {
  final controller = TextEditingController();
  var size = 0.035;
  final result = await showDialog<({String text, double size})>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(context.l10n.t('toolText')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 1,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: context.l10n.t('textMarkHint'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.text_fields_rounded, size: 18),
                Expanded(
                  child: Slider(
                    value: size,
                    min: 0.018,
                    max: 0.08,
                    onChanged: (value) => setState(() => size = value),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(
                dialogContext,
                text.isEmpty ? null : (text: text, size: size),
              );
            },
            child: Text(context.l10n.t('done')),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}

/// Lets the user draw a signature. Returns strokes in units of the pad width,
/// or null when cancelled or empty.
Future<List<List<Offset>>?> showSignatureDialog(BuildContext context) {
  return showDialog<List<List<Offset>>>(
    context: context,
    builder: (dialogContext) => const _SignatureDialog(),
  );
}

class _SignatureDialog extends StatefulWidget {
  const _SignatureDialog();

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  static const _padHeight = 170.0;
  final List<List<Offset>> _strokes = [];
  double _width = 300;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.t('toolSignature')),
      content: LayoutBuilder(
        builder: (context, constraints) {
          _width = constraints.maxWidth.isFinite ? constraints.maxWidth : 300;
          return SizedBox(
            width: _width,
            height: _padHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black26),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GestureDetector(
                  onPanStart: (details) =>
                      setState(() => _strokes.add([details.localPosition])),
                  onPanUpdate: (details) =>
                      setState(() => _strokes.last.add(details.localPosition)),
                  child: CustomPaint(
                    size: Size(_width, _padHeight),
                    painter: _PadPainter([
                      for (final s in _strokes) List<Offset>.of(s),
                    ]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear),
          child: Text(l10n.t('clear')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.t('cancel')),
        ),
        FilledButton(
          onPressed: _strokes.isEmpty
              ? null
              : () => Navigator.pop(context, [
                  for (final stroke in _strokes)
                    [for (final point in stroke) point / _width],
                ]),
          child: Text(l10n.t('done')),
        ),
      ],
    );
  }
}

class _PadPainter extends CustomPainter {
  const _PadPainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.5, paint);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_PadPainter oldDelegate) => true;
}
