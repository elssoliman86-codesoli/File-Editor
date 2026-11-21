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
import '../pdf_editor/pdf_edit_toolbar.dart';
import '../pdf_editor/pdf_flatten_service.dart';
import '../pdf_editor/pdf_marks.dart';
import '../pdf_editor/pdf_marks_layer.dart';

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
  final _store = PdfMarkStore();
  final _settings = ValueNotifier<PdfEditSettings>(const PdfEditSettings());

  // Page position and count change constantly while scrolling. They live in
  // notifiers so only the small page indicator rebuilds, not the whole screen.
  final _pageNumber = ValueNotifier<int>(1);
  final _pageCount = ValueNotifier<int>(0);

  bool _searchVisible = false;
  bool _night = false;
  bool _chromeVisible = true;
  bool _editing = false;
  bool _saving = false;
  bool _hasMarks = false;
  bool _panLocked = false;
  int _revision = 0;
  List<PdfOutlineNode> _outline = const [];

  // The viewer compares its params on every rebuild; a fresh object each time
  // makes it re-evaluate layout. Keep one instance per configuration instead.
  PdfViewerParams? _params;
  String? _paramsKey;

  @override
  void initState() {
    super.initState();
    _searcher = PdfTextSearcher(_controller)..addListener(_onSearch);
    _store.addListener(_onStore);
    _settings.addListener(_onSettings);
  }

  void _onSearch() {
    if (mounted && _searchVisible) setState(() {});
  }

  void _onStore() {
    final has = _store.hasMarks;
    if (has != _hasMarks && mounted) setState(() => _hasMarks = has);
  }

  void _onSettings() {
    final lock = _editing && _settings.value.capturesTouch;
    if (lock != _panLocked && mounted) setState(() => _panLocked = lock);
  }

  @override
  void dispose() {
    _searcher
      ..removeListener(_onSearch)
      ..dispose();
    _store
      ..removeListener(_onStore)
      ..dispose();
    _settings
      ..removeListener(_onSettings)
      ..dispose();
    _pageNumber.dispose();
    _pageCount.dispose();
    _searchController.dispose();
    super.dispose();
  }

  PdfViewerParams _viewerParams() {
    final overlays = _editing || _hasMarks;
    final pan = !(_editing && _settings.value.capturesTouch);
    final key = '$_night|$overlays|$pan';
    if (_params != null && _paramsKey == key) return _params!;
    _paramsKey = key;
    return _params = PdfViewerParams(
      backgroundColor: _night ? Colors.black : const Color(0xFF303642),
      pageImageColorFilter: _night ? _invert : null,
      maxImageBytesCachedOnMemory: 64 * 1024 * 1024,
      panEnabled: pan,
      pagePaintCallbacks: [_searcher.pageTextMatchPaintCallback],
      pageOverlaysBuilder: overlays ? _pageOverlays : null,
      onPageChanged: (pageNumber) => _pageNumber.value = pageNumber ?? 1,
      onDocumentChanged: _onDocumentChanged,
    );
  }

  Future<void> _onDocumentChanged(PdfDocument? document) async {
    if (document == null) return;
    _pageCount.value = document.pages.length;
    _outline = await document.loadOutline();
  }

  List<Widget> _pageOverlays(BuildContext context, Rect pageRect, PdfPage page) {
    return [
      Positioned.fill(
        child: PdfPageMarksLayer(
          key: ValueKey('marks-${page.pageNumber}'),
          page: page.pageNumber,
          store: _store,
          settings: _settings,
          onTextRequest: _addText,
        ),
      ),
    ];
  }

  Future<void> _addText(int page, Offset position) async {
    final result = await showTextMarkDialog(context);
    if (result == null) return;
    _store.commit(page, [
      ..._store.marksFor(page),
      TextMark(
        position: position,
        text: result.text,
        color: _settings.value.color,
        size: result.size,
      ),
    ]);
  }

  Future<void> _addSignature() async {
    final strokes = await showSignatureDialog(context);
    if (strokes == null || !_controller.isReady || !mounted) return;
    final number = _pageNumber.value;
    final page = _controller.document.pages[number - 1];
    // Placed in the middle of the current page at 30% of its width; the Move
    // tool repositions it.
    const scale = 0.3;
    final origin = Offset(0.35, page.height / page.width * 0.45);
    _store.commit(number, [
      ..._store.marksFor(number),
      InkMark(
        strokes: [
          for (final stroke in strokes)
            [for (final point in stroke) origin + point * scale],
        ],
        color: _settings.value.color,
        width: _settings.value.width * 0.7,
      ),
    ]);
    _settings.value = _settings.value.copyWith(tool: MarkTool.move);
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _saveEdits() async {
    if (!_store.hasMarks || _saving) return;
    final l10n = context.l10n;
    final proceed = await _confirm(
      l10n.t('flattenNoticeTitle'),
      l10n.t('flattenNotice'),
      l10n.t('save'),
    );
    if (!proceed || !mounted) return;
    setState(() => _saving = true);
    try {
      final bytes = await const PdfAnnotationWriter().write(
        sourcePath: widget.record.originalPath,
        marks: {
          for (final page in _store.editedPages) page: _store.marksFor(page),
        },
        passwordProvider: _askPassword,
      );
      final base = widget.record.name.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      await DocumentExportService(ref.read(storageChannelProvider)).save(
        name: '$base (edited).pdf',
        kind: DocumentKind.pdf,
        bytes: bytes,
      );
      await ref.read(workspaceProvider).markExported(widget.record, bytes);
      if (!mounted) return;
      _store.clear();
      setState(() {
        _editing = false;
        _revision++;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('savedVerified'))));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.t('errorSave')}\n$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leaveEditing() async {
    if (_hasMarks) {
      final l10n = context.l10n;
      final discard = await _confirm(
        l10n.t('discardTitle'),
        l10n.t('discardBody'),
        l10n.t('discard'),
      );
      if (!discard) return;
      _store.clear();
    }
    if (mounted) {
      _settings.value = _settings.value.copyWith(tool: MarkTool.hand);
      setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_hasMarks,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirm(
          l10n.t('discardTitle'),
          l10n.t('discardBody'),
          l10n.t('discard'),
        );
        if (discard && context.mounted) {
          _store.clear();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: _night ? Colors.black : const Color(0xFF303642),
        appBar: _editing
            ? _editAppBar(l10n)
            : (_chromeVisible ? _viewAppBar(l10n) : null),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _editing
                      ? null
                      : () => setState(() => _chromeVisible = !_chromeVisible),
                  child: PdfViewer.file(
                    widget.record.originalPath,
                    key: ValueKey('pdf-$_revision'),
                    controller: _controller,
                    passwordProvider: _askPassword,
                    params: _viewerParams(),
                  ),
                ),
              ),
              if (_searchVisible && !_editing) _searchBar(l10n),
              if (_chromeVisible && !_editing) _pageBar(),
              if (_saving)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x88000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: _editing
            ? PdfEditToolbar(settings: _settings, onSignature: _addSignature)
            : null,
      ),
    );
  }

  AppBar _viewAppBar(AppLocalizations l10n) => AppBar(
    title: Text(widget.record.name, overflow: TextOverflow.ellipsis),
    actions: [
      IconButton(
        tooltip: l10n.t('editPdf'),
        onPressed: () => setState(() => _editing = true),
        icon: const Icon(Icons.edit_note_rounded),
      ),
      IconButton(
        tooltip: l10n.t('search'),
        onPressed: () => setState(() => _searchVisible = !_searchVisible),
        icon: const Icon(Icons.search_rounded),
      ),
      IconButton(
        tooltip: l10n.t('organize'),
        onPressed: () => context.push('/pdf-organize/${widget.record.id}'),
        icon: const Icon(Icons.grid_view_rounded),
      ),
      PopupMenuButton<String>(
        onSelected: _menu,
        itemBuilder: (_) => [
          PopupMenuItem(value: 'outline', child: Text(l10n.t('documents'))),
          PopupMenuItem(value: 'thumbnails', child: Text(l10n.t('organize'))),
          PopupMenuItem(value: 'text', child: Text(l10n.t('extractText'))),
          PopupMenuItem(value: 'night', child: Text(l10n.t('darkMode'))),
          PopupMenuItem(value: 'share', child: Text(l10n.t('share'))),
          PopupMenuItem(value: 'print', child: Text(l10n.t('print'))),
        ],
      ),
    ],
  );

  AppBar _editAppBar(AppLocalizations l10n) => AppBar(
    leading: IconButton(
      tooltip: l10n.t('cancel'),
      onPressed: _saving ? null : _leaveEditing,
      icon: const Icon(Icons.close_rounded),
    ),
    title: Text(l10n.t('editPdf')),
    actions: [
      ListenableBuilder(
        listenable: _store,
        builder: (context, _) => Row(
          children: [
            IconButton(
              tooltip: l10n.t('undo'),
              onPressed: _store.canUndo ? _store.undo : null,
              icon: const Icon(Icons.undo_rounded),
            ),
            IconButton(
              tooltip: l10n.t('redo'),
              onPressed: _store.canRedo ? _store.redo : null,
              icon: const Icon(Icons.redo_rounded),
            ),
            IconButton(
              tooltip: l10n.t('savePdfCopy'),
              onPressed: _hasMarks && !_saving ? _saveEdits : null,
              icon: const Icon(Icons.save_outlined),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _searchBar(AppLocalizations l10n) => Positioned(
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
  );

  Widget _pageBar() => Positioned(
    left: 16,
    right: 16,
    bottom: 14,
    child: Center(
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(28),
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: ValueListenableBuilder<int>(
            valueListenable: _pageCount,
            builder: (context, count, _) => ValueListenableBuilder<int>(
              valueListenable: _pageNumber,
              builder: (context, page, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      if (_controller.isReady) {
                        _controller.goToPage(
                          pageNumber: (page - 1).clamp(1, count),
                        );
                      }
                    },
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                  InkWell(
                    onTap: _goToPage,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        '$page / ${count == 0 ? '…' : count}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_controller.isReady) {
                        _controller.goToPage(
                          pageNumber: (page + 1).clamp(1, count),
                        );
                      }
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
    ),
  );

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
      startPageNumber: _pageNumber.value,
    );
  }

  Future<void> _goToPage() async {
    final controller = TextEditingController(text: '${_pageNumber.value}');
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
    if (value != null && value >= 1 && value <= _pageCount.value)
      _controller.goToPage(pageNumber: value);
  }

  Future<void> _menu(String action) async {
    if (action == 'night') {
      setState(() => _night = !_night);
      return;
    }
    if (action == 'edit') {
      setState(() => _editing = true);
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
