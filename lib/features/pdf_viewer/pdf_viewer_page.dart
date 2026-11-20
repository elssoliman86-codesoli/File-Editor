import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:document_core/document_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/document_export_service.dart';
import '../../data/models/document_record.dart';
import '../../l10n/app_localizations.dart';

class PdfViewerPage extends ConsumerStatefulWidget {
  const PdfViewerPage({required this.record, super.key});
  final DocumentRecord record;

  @override
  ConsumerState<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends ConsumerState<PdfViewerPage> {
  final _controller = PdfViewerController();
  final _searchController = TextEditingController();
  late final PdfTextSearcher _searcher;
  bool _searchVisible = false;
  bool _night = false;
  bool _chromeVisible = true;
  int _page = 1;
  int _pages = 0;
  List<PdfOutlineNode> _outline = const [];

  @override
  void initState() {
    super.initState();
    _searcher = PdfTextSearcher(_controller)..addListener(_update);
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searcher
      ..removeListener(_update)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: _night ? Colors.black : const Color(0xFF303642),
      appBar: _chromeVisible
          ? AppBar(
              title: Text(widget.record.name, overflow: TextOverflow.ellipsis),
              actions: [
                IconButton(
                  tooltip: l10n.t('search'),
                  onPressed: () =>
                      setState(() => _searchVisible = !_searchVisible),
                  icon: const Icon(Icons.search_rounded),
                ),
                IconButton(
                  tooltip: l10n.t('organize'),
                  onPressed: () =>
                      context.push('/pdf-organize/${widget.record.id}'),
                  icon: const Icon(Icons.grid_view_rounded),
                ),
                PopupMenuButton<String>(
                  onSelected: _menu,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'outline',
                      child: Text(l10n.t('documents')),
                    ),
                    PopupMenuItem(
                      value: 'thumbnails',
                      child: Text(l10n.t('organize')),
                    ),
                    PopupMenuItem(
                      value: 'text',
                      child: Text(l10n.t('extractText')),
                    ),
                    PopupMenuItem(
                      value: 'night',
                      child: Text(l10n.t('darkMode')),
                    ),
                    PopupMenuItem(value: 'share', child: Text(l10n.t('share'))),
                    PopupMenuItem(value: 'print', child: Text(l10n.t('print'))),
                  ],
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _chromeVisible = !_chromeVisible),
                child: PdfViewer.file(
                  widget.record.originalPath,
                  controller: _controller,
                  passwordProvider: _askPassword,
                  params: PdfViewerParams(
                    backgroundColor: _night
                        ? Colors.black
                        : const Color(0xFF303642),
                    pageImageColorFilter: _night ? _invert : null,
                    maxImageBytesCachedOnMemory: 64 * 1024 * 1024,
                    pagePaintCallbacks: [_searcher.pageTextMatchPaintCallback],
                    onPageChanged: (pageNumber) {
                      if (mounted) setState(() => _page = pageNumber ?? 1);
                    },
                    onDocumentChanged: (document) async {
                      if (document == null) return;
                      _pages = document.pages.length;
                      _outline = await document.loadOutline();
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              ),
            ),
            if (_searchVisible)
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: Material(
                  borderRadius: BorderRadius.circular(16),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              filled: false,
                              hintText: l10n.t('search'),
                            ),
                            onSubmitted: _startSearch,
                          ),
                        ),
                        Text(
                          '${_searcher.currentIndex == null ? 0 : _searcher.currentIndex! + 1}/${_searcher.matches.length}',
                        ),
                        IconButton(
                          onPressed: () {
                            if (_searcher.hasMatches) _searcher.goToPrevMatch();
                          },
                          icon: const Icon(Icons.keyboard_arrow_up_rounded),
                        ),
                        IconButton(
                          onPressed: () {
                            if (_searcher.hasMatches) _searcher.goToNextMatch();
                          },
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                        IconButton(
                          onPressed: () {
                            _searcher.resetTextSearch();
                            setState(() => _searchVisible = false);
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_chromeVisible)
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Center(
                  child: Material(
                    color: Theme.of(context).colorScheme.surface
                        .withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(28),
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              if (_controller.isReady)
                                _controller.goToPage(
                                  pageNumber: (_page - 1).clamp(1, _pages),
                                );
                            },
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                          InkWell(
                            onTap: _goToPage,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                '$_page / ${_pages == 0 ? '…' : _pages}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (_controller.isReady)
                                _controller.goToPage(
                                  pageNumber: (_page + 1).clamp(1, _pages),
                                );
                            },
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          IconButton(
                            onPressed: () {
                              if (_controller.isReady) _controller.zoomDown();
                            },
                            icon: const Icon(Icons.zoom_out_rounded),
                          ),
                          IconButton(
                            onPressed: () {
                              if (_controller.isReady) _controller.zoomUp();
                            },
                            icon: const Icon(Icons.zoom_in_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askPassword() async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.t('pdfPassword')),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(context.l10n.t('unlock')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _startSearch(String query) {
    if (query.isEmpty) return;
    _searcher.startTextSearch(
      query,
      caseInsensitive: true,
      startPageNumber: _page,
    );
  }

  Future<void> _goToPage() async {
    final controller = TextEditingController(text: '$_page');
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.t('page')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, int.tryParse(controller.text)),
            child: Text(context.l10n.t('done')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value >= 1 && value <= _pages)
      _controller.goToPage(pageNumber: value);
  }

  Future<void> _menu(String action) async {
    if (action == 'night') {
      setState(() => _night = !_night);
      return;
    }
    if (action == 'thumbnails') {
      await _showThumbnails();
      return;
    }
    if (action == 'outline') {
      await _showOutline();
      return;
    }
    if (action == 'text') {
      await _extractText();
      return;
    }
    final bytes = await File(widget.record.originalPath).readAsBytes();
    final exporter = DocumentExportService(ref.read(storageChannelProvider));
    if (action == 'share')
      await exporter.share(
        widget.record.name,
        bytes,
        DocumentKind.pdf.mimeType,
      );
    if (action == 'print') await exporter.printPdf(bytes, widget.record.name);
  }

  Future<void> _showThumbnails() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * .72,
        child: PdfDocumentViewBuilder.file(
          widget.record.originalPath,
          passwordProvider: _askPassword,
          builder: (context, document) {
            if (document == null)
              return const Center(child: CircularProgressIndicator());
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: .68,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: document.pages.length,
              itemBuilder: (context, index) => InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _controller.goToPage(pageNumber: index + 1);
                },
                child: Column(
                  children: [
                    Expanded(
                      child: PdfPageView(
                        document: document,
                        pageNumber: index + 1,
                        alignment: Alignment.center,
                      ),
                    ),
                    Text('${index + 1}'),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showOutline() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: _outline.isEmpty
            ? Center(child: Text(context.l10n.t('noResults')))
            : ListView(
                children: _outline
                    .map(
                      (node) => ListTile(
                        title: Text(node.title),
                        leading: const Icon(Icons.bookmark_outline_rounded),
                        onTap: () {
                          if (node.dest != null)
                            _controller.goToPage(
                              pageNumber: node.dest!.pageNumber,
                            );
                          Navigator.pop(context);
                        },
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }

  Future<void> _extractText() async {
    final document = await PdfDocument.openFile(
      widget.record.originalPath,
      passwordProvider: _askPassword,
    );
    try {
      final output = StringBuffer();
      for (final page in document.pages) {
        final text = await page.loadText();
        output
          ..writeln('--- ${context.l10n.t('page')} ${page.pageNumber} ---')
          ..writeln(text?.fullText ?? '');
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(output.toString()),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: output.toString()),
                      ),
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(context.l10n.t('share')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final bytes = Uint8List.fromList(
                          output.toString().codeUnits,
                        );
                        await DocumentExportService(
                          ref.read(storageChannelProvider),
                        ).save(
                          name: '${widget.record.name}.txt',
                          kind: DocumentKind.txt,
                          bytes: bytes,
                        );
                      },
                      child: Text(context.l10n.t('exportTxt')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } finally {
      await document.dispose();
    }
  }

  static const _invert = ColorFilter.matrix([
    -1,
    0,
    0,
    0,
    255,
    0,
    -1,
    0,
    0,
    255,
    0,
    0,
    -1,
    0,
    255,
    0,
    0,
    0,
    1,
    0,
  ]);
}
