import 'dart:async';

import 'package:document_core/document_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/document_export_service.dart';
import '../../data/models/document_record.dart';
import '../../l10n/app_localizations.dart';

class PdfOrganizerPage extends ConsumerStatefulWidget {
  const PdfOrganizerPage({this.recordId, this.records = const [], super.key});
  final String? recordId;
  final List<DocumentRecord> records;

  @override
  ConsumerState<PdfOrganizerPage> createState() => _PdfOrganizerPageState();
}

class _PageItem {
  _PageItem({required this.id, required this.page, required this.sourceName, required this.originalNumber, this.rotation});
  final int id;
  final PdfPage page;
  final String sourceName;
  final int originalNumber;
  final PdfPageRotation? rotation;

  PdfPage get effective => rotation == null ? page : page.rotatedTo(rotation!);
  _PageItem copyWith({PdfPageRotation? rotation}) => _PageItem(id: id, page: page, sourceName: sourceName, originalNumber: originalNumber, rotation: rotation ?? this.rotation);
}

class _PdfOrganizerPageState extends ConsumerState<PdfOrganizerPage> {
  final List<PdfDocument> _documents = [];
  final List<_PageItem> _pages = [];
  bool _loading = true;
  bool _saving = false;
  Object? _error;
  int _id = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final records = [...widget.records];
      if (widget.recordId != null) {
        final record = await ref.read(workspaceProvider).byId(widget.recordId!);
        if (record != null) records.add(record);
      }
      for (final record in records) {
        final document = await PdfDocument.openFile(record.originalPath);
        _documents.add(document);
        for (final page in document.pages) {
          _pages.add(_PageItem(id: _id++, page: page, sourceName: record.name, originalNumber: page.pageNumber));
        }
      }
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (mounted) setState(() { _error = error; _loading = false; });
    }
  }

  @override
  void dispose() {
    for (final document in _documents) {
      unawaited(document.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('organize')),
        actions: [TextButton.icon(onPressed: _pages.isEmpty || _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(l10n.t('save')))],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$_error')))
                : Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xFFFFB020).withValues(alpha: .1),
                        child: Text(l10n.t('pdfEditNotice'), style: const TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        child: ReorderableListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _pages.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              final item = _pages.removeAt(oldIndex);
                              _pages.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final item = _pages[index];
                            return Card(
                              key: ValueKey(item.id),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      height: 140,
                                      child: PdfPageView(
                                        document: item.page.document,
                                        pageNumber: item.originalNumber,
                                        rotationOverride: item.rotation,
                                        alignment: Alignment.center,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${l10n.t('page')} ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 5),
                                          Text(item.sourceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                                          Text('${l10n.t('page')} ${item.originalNumber}', style: Theme.of(context).textTheme.bodySmall),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            children: [
                                              IconButton(tooltip: l10n.t('rotate'), onPressed: () => setState(() => _pages[index] = item.copyWith(rotation: (item.rotation ?? item.page.rotation).rotateCW90)), icon: const Icon(Icons.rotate_right_rounded)),
                                              IconButton(tooltip: l10n.t('duplicate'), onPressed: () => setState(() => _pages.insert(index + 1, _PageItem(id: _id++, page: item.page, sourceName: item.sourceName, originalNumber: item.originalNumber, rotation: item.rotation))), icon: const Icon(Icons.copy_rounded)),
                                              IconButton(tooltip: l10n.t('delete'), onPressed: () => setState(() => _pages.removeAt(index)), icon: const Icon(Icons.delete_outline_rounded)),
                                              ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_indicator_rounded)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
      bottomNavigationBar: _saving ? const LinearProgressIndicator() : null,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    PdfDocument? output;
    PdfDocument? verification;
    try {
      output = await PdfDocument.createNew(sourceName: 'midad-organized-${DateTime.now().microsecondsSinceEpoch}');
      output.pages = _pages.map((item) => item.effective).toList();
      final bytes = await output.encodePdf();
      verification = await PdfDocument.openData(bytes, sourceName: 'verify-organized');
      if (verification.pages.length != _pages.length) throw StateError('PDF page-count verification failed.');
      final receipt = await DocumentExportService(ref.read(storageChannelProvider)).save(
        name: 'midad-organized-${DateTime.now().millisecondsSinceEpoch}.pdf',
        kind: DocumentKind.pdf,
        bytes: bytes,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.l10n.t('savedVerified')} · ${receipt.byteCount} bytes')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.l10n.t('errorSave')}\n$error')));
    } finally {
      await verification?.dispose();
      await output?.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }
}
