import 'dart:io';
import 'dart:ui' as ui;

import 'package:docx_engine/docx_engine.dart';

import 'package:document_core/document_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/document_export_service.dart';
import '../../data/models/document_record.dart';
import '../../l10n/app_localizations.dart';
import 'image_pdf_codec.dart';
import 'pdf_organizer_page.dart';

class PdfToolsPage extends StatelessWidget {
  const PdfToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tools = <(String, String, IconData, Color)>[
      ('merge', l10n.t('merge'), Icons.merge_type_rounded, const Color(0xFFFF7D87)),
      ('images', l10n.t('imagesToPdf'), Icons.collections_outlined, const Color(0xFFFFB020)),
      ('organize', l10n.t('organize'), Icons.grid_view_rounded, const Color(0xFF5C9DFF)),
      ('extract', l10n.t('extractPages'), Icons.content_cut_rounded, const Color(0xFF2ECC8F)),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('pdfTools'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(16)), child: Text(l10n.t('pdfEditNotice'), style: const TextStyle(height: 1.7))),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.25, mainAxisSpacing: 12, crossAxisSpacing: 12),
            itemCount: tools.length,
            itemBuilder: (context, index) {
              final tool = tools[index];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfToolWorkspace(mode: tool.$1))),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: tool.$4.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Icon(tool.$3, color: tool.$4, size: 28)),
                        Text(tool.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class PdfToolWorkspace extends ConsumerStatefulWidget {
  const PdfToolWorkspace({required this.mode, this.initialRecord, super.key});
  final String mode;
  final DocumentRecord? initialRecord;

  @override
  ConsumerState<PdfToolWorkspace> createState() => _PdfToolWorkspaceState();
}

class _PdfToolWorkspaceState extends ConsumerState<PdfToolWorkspace> {
  final List<DocumentRecord> _records = [];
  final _range = TextEditingController(text: '1-');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialRecord != null) _records.add(widget.initialRecord!);
  }

  @override
  void dispose() {
    _range.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = switch (widget.mode) {
      'images' => l10n.t('imagesToPdf'),
      'organize' => l10n.t('organize'),
      'extract' => l10n.t('extractPages'),
      _ => l10n.t('merge'),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.add_rounded),
                label: Text(widget.mode == 'images' ? l10n.t('addImages') : l10n.t('addFiles')),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _records.isEmpty
                    ? Center(child: Text(l10n.t('emptyHint'), textAlign: TextAlign.center))
                    : ListView.separated(
                        itemCount: _records.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => Card(
                          child: ListTile(
                            leading: Icon(widget.mode == 'images' ? Icons.image_outlined : Icons.picture_as_pdf_outlined),
                            title: Text(_records[index].name),
                            trailing: IconButton(onPressed: () => setState(() => _records.removeAt(index)), icon: const Icon(Icons.close_rounded)),
                          ),
                        ),
                      ),
              ),
              if (widget.mode == 'extract')
                Padding(padding: const EdgeInsets.only(bottom: 16), child: TextField(controller: _range, decoration: InputDecoration(labelText: l10n.t('pageRange')))),
              if (_busy) const Padding(padding: EdgeInsets.only(bottom: 16), child: LinearProgressIndicator()),
              FilledButton.icon(
                onPressed: _records.isEmpty || _busy ? null : _run,
                icon: Icon(widget.mode == 'extract' ? Icons.content_cut_rounded : Icons.arrow_forward_rounded),
                label: Text(widget.mode == 'images' ? l10n.t('createPdf') : widget.mode == 'extract' ? l10n.t('extractPages') : l10n.t('organize')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick() async {
    setState(() => _busy = true);
    try {
      final records = await ref.read(workspaceProvider).importFiles(multiple: widget.mode != 'extract', imagesOnly: widget.mode == 'images');
      setState(() => _records.addAll(records.where((r) => widget.mode == 'images' ? r.kind == DocumentKind.image : r.kind == DocumentKind.pdf)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run() async {
    if (widget.mode == 'images') { await _imagesToPdf(); return; }
    if (widget.mode == 'extract') { await _extract(); return; }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfOrganizerPage(records: _records)));
  }

  Future<void> _imagesToPdf() async {
    setState(() => _busy = true);
    PdfDocument? output;
    final sources = <PdfDocument>[];
    try {
      output = await PdfDocument.createNew(sourceName: 'midad-images-${DateTime.now().microsecondsSinceEpoch}');
      final pages = <PdfPage>[];
      for (final record in _records) {
        final bytes = await File(record.originalPath).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 2000);
        final frame = await codec.getNextFrame();
        final rgba = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final jpeg = await rgbaToJpeg(rgba!.buffer.asUint8List(), frame.image.width, frame.image.height);
        final source = await PdfDocument.createFromJpegData(
          jpeg,
          width: 595,
          height: (595 * frame.image.height / frame.image.width).clamp(100, 842).toDouble(),
          sourceName: record.name,
        );
        sources.add(source);
        pages.addAll(source.pages);
        frame.image.dispose();
        codec.dispose();
      }
      output.pages = pages;
      final bytes = await output.encodePdf();
      await DocumentExportService(ref.read(storageChannelProvider)).save(name: 'images-${DateTime.now().millisecondsSinceEpoch}.pdf', kind: DocumentKind.pdf, bytes: bytes);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.t('savedVerified'))));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.l10n.t('errorSave')}\n$error')));
    } finally {
      for (final source in sources) await source.dispose();
      await output?.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _extract() async {
    setState(() => _busy = true);
    PdfDocument? source;
    PdfDocument? output;
    try {
      source = await PdfDocument.openFile(_records.first.originalPath);
      final pages = parsePageRanges(_range.text, source.pages.length);
      output = await PdfDocument.createNew(sourceName: 'midad-extract');
      output.pages = pages.map((number) => source!.pages[number - 1]).toList();
      final bytes = await output.encodePdf();
      await DocumentExportService(ref.read(storageChannelProvider)).save(name: 'extract-${DateTime.now().millisecondsSinceEpoch}.pdf', kind: DocumentKind.pdf, bytes: bytes);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.t('savedVerified'))));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      await output?.dispose();
      await source?.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }
}
