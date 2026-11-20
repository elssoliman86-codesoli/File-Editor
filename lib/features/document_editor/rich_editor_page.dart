import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:arabic_text/arabic_text.dart';
import 'package:docx_engine/docx_engine.dart';
import 'package:document_core/document_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:txt_engine/txt_engine.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/document_export_service.dart';
import '../../core/settings/settings_controller.dart';
import '../../data/models/document_record.dart';
import '../../data/models/editor_session.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/compatibility_banner.dart';
import '../../shared/widgets/search_replace_bar.dart';

class RichEditorPage extends ConsumerStatefulWidget {
  const RichEditorPage({required this.record, super.key});
  final DocumentRecord record;

  @override
  ConsumerState<RichEditorPage> createState() => _RichEditorPageState();
}

class _RichEditorPageState extends ConsumerState<RichEditorPage> {
  late final QuillController _controller;
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _nameController = TextEditingController();
  EditorSession? _session;
  Timer? _autosave;
  Object? _loadError;
  bool _searchVisible = false;
  bool _dirty = false;
  bool _saving = false;
  int _saveGeneration = 0;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.record.name;
    _controller = QuillController.basic();
    _load();
  }

  Future<void> _load() async {
    try {
      final session = await ref.read(workspaceProvider).loadSession(widget.record);
      if (!mounted) return;
      _session = session;
      _controller.document = Document.fromJson(session.operations);
      _controller.addListener(_onEdit);
      setState(() {});
      _scheduleAutosave();
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  void _onEdit() {
    if (!_dirty && mounted) setState(() => _dirty = true);
    _saveGeneration++;
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    _autosave?.cancel();
    final seconds = ref.read(settingsProvider).autosaveSeconds;
    _autosave = Timer(Duration(seconds: seconds), _saveRecovery);
  }

  Future<void> _saveRecovery() async {
    final session = _session;
    if (session == null) return;
    await ref.read(workspaceProvider).saveRecovery(session.record, operations: _operations);
  }

  List<Map<String, dynamic>> get _operations => _controller.document.toDelta().toJson()
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();

  @override
  void dispose() {
    _autosave?.cancel();
    if (_session != null) {
      unawaited(ref.read(workspaceProvider).saveRecovery(_session!.record, operations: _operations));
    }
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loadError != null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('${l10n.t('errorOpen')}\n$_loadError'))));
    }
    if (_session == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final stats = TextStatistics.from(_controller.document.toPlainText());
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _saveRecovery();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: TextField(
            controller: _nameController,
            decoration: const InputDecoration(border: InputBorder.none, fillColor: Colors.transparent, filled: false, isDense: true),
            style: const TextStyle(fontWeight: FontWeight.w700),
            onChanged: (_) => ref.read(workspaceProvider).rename(widget.record, _nameController.text),
          ),
          actions: [
            IconButton(tooltip: l10n.t('search'), onPressed: () => setState(() => _searchVisible = !_searchVisible), icon: const Icon(Icons.search_rounded)),
            IconButton(tooltip: l10n.t('save'), onPressed: _saving ? null : _saveDocx, icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined)),
            PopupMenuButton<String>(
              onSelected: _menuAction,
              itemBuilder: (_) => [
                PopupMenuItem(value: 'pdf', child: Text(l10n.t('exportPdf'))),
                PopupMenuItem(value: 'txt', child: Text(l10n.t('exportTxt'))),
                PopupMenuItem(value: 'share', child: Text(l10n.t('share'))),
                PopupMenuItem(value: 'print', child: Text(l10n.t('print'))),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              CompatibilityBanner(message: l10n.t('docxEditNotice'), onDetails: _showWarnings),
              if (_searchVisible)
                SearchReplaceBar(
                  source: _controller.document.toPlainText(),
                  onChanged: (_) {},
                  onNavigate: (match) => _controller.updateSelection(TextSelection(baseOffset: match.start, extentOffset: match.end), ChangeSource.local),
                  onReplaceAll: _replaceAll,
                  onClose: () => setState(() => _searchVisible = false),
                ),
              Expanded(
                child: Container(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111827) : const Color(0xFFE9EDF5),
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Material(
                        color: Colors.white,
                        elevation: 4,
                        shadowColor: Colors.black26,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 28),
                          child: QuillEditor(
                            controller: _controller,
                            focusNode: _focusNode,
                            scrollController: _scrollController,
                            config: QuillEditorConfig(
                              scrollable: true,
                              expands: false,
                              minHeight: 720,
                              maxContentWidth: 760,
                              padding: const EdgeInsets.all(28),
                              placeholder: l10n.t('selectTemplate'),
                              customStyles: DefaultStyles(
                                paragraph: DefaultTextBlockStyle(
                                  TextStyle(fontFamily: 'NotoNaskhArabic', fontSize: ref.watch(settingsProvider).editorFontSize, color: Colors.black87, height: 1.7),
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(0, 8),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                              ),
                              embedBuilders: [const _Base64ImageEmbedBuilder()],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                color: Theme.of(context).colorScheme.surface,
                elevation: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 68,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: QuillSimpleToolbar(
                          controller: _controller,
                          config: const QuillSimpleToolbarConfig(
                            multiRowsDisplay: false,
                            showDividers: false,
                            showAlignmentButtons: true,
                            showDirection: true,
                            showFontFamily: false,
                            showFontSize: true,
                            showInlineCode: false,
                            showCodeBlock: false,
                            showListCheck: false,
                            showClipboardPaste: false,
                            showSearchButton: false,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Row(
                        children: [
                          IconButton.filledTonal(tooltip: 'Insert image', onPressed: _insertImage, icon: const Icon(Icons.image_outlined)),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(tooltip: 'Page break', onPressed: _insertPageBreak, icon: const Icon(Icons.insert_page_break_outlined)),
                          const Spacer(),
                          Text('${stats.words} ${l10n.t('words')} · ${stats.characters} ${l10n.t('characters')}', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _insertImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 88);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.length > 20 * 1024 * 1024) return;
    final mime = image.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final data = 'data:$mime;base64,${base64Encode(bytes)}';
    final index = _controller.selection.extentOffset;
    _controller
      ..replaceText(index, 0, BlockEmbed.image(data), null)
      ..updateSelection(TextSelection.collapsed(offset: index + 1), ChangeSource.local);
  }

  void _insertPageBreak() {
    final index = _controller.selection.extentOffset;
    _controller
      ..replaceText(index, 0, '\n', null)
      ..formatText(index, 1, Attribute.clone(Attribute.blockQuote, true));
  }

  void _replaceAll(({String query, String replacement, SearchOptions options}) request) {
    final ops = _operations;
    final matches = const TextSearchEngine().findAll(_controller.document.toPlainText(), request.query, options: request.options);
    if (matches.isEmpty) return;
    var logical = 0;
    final updated = <Map<String, dynamic>>[];
    for (final op in ops) {
      final insert = op['insert'];
      if (insert is! String) { updated.add(op); logical++; continue; }
      final end = logical + insert.length;
      final relevant = matches.where((m) => m.start >= logical && m.end <= end).toList();
      if (relevant.isEmpty) { updated.add(op); logical = end; continue; }
      var cursor = 0;
      for (final match in relevant) {
        final start = match.start - logical;
        final stop = match.end - logical;
        if (start < cursor) continue;
        if (start > cursor) updated.add({'insert': insert.substring(cursor, start), if (op['attributes'] != null) 'attributes': op['attributes']});
        updated.add({'insert': request.replacement, if (op['attributes'] != null) 'attributes': op['attributes']});
        cursor = stop;
      }
      if (cursor < insert.length) updated.add({'insert': insert.substring(cursor), if (op['attributes'] != null) 'attributes': op['attributes']});
      logical = end;
    }
    _controller.document = Document.fromJson(updated);
    setState(() => _dirty = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${matches.length} ${context.l10n.t('replace')}')));
  }

  Future<void> _menuAction(String action) async {
    final exporter = DocumentExportService(ref.read(storageChannelProvider));
    final text = _controller.document.toPlainText();
    try {
      if (action == 'pdf') {
        final bytes = await exporter.textToPdf(title: _nameController.text, text: text);
        await _saveBytes('${_baseName()}.pdf', DocumentKind.pdf, bytes);
      } else if (action == 'txt') {
        await _saveBytes('${_baseName()}.txt', DocumentKind.txt, Uint8List.fromList(utf8.encode(text)));
      } else if (action == 'share') {
        final bytes = await _buildDocx();
        await exporter.share(_nameController.text, bytes, DocumentKind.docx.mimeType);
      } else if (action == 'print') {
        await exporter.printText(title: _nameController.text, text: text);
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.l10n.t('errorSave')}\n$error')));
    }
  }

  Future<Uint8List> _buildDocx() async {
    final session = _session!;
    return ref.read(workspaceProvider).buildDocument(session, operations: _operations);
  }

  Future<void> _saveDocx() async {
    setState(() => _saving = true);
    try {
      final bytes = await _buildDocx();
      const DocxEngine().open(bytes);
      await _saveBytes(_nameController.text, DocumentKind.docx, bytes);
      await ref.read(workspaceProvider).markExported(widget.record, bytes);
      if (mounted) setState(() => _dirty = false);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.l10n.t('errorSave')}\n$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveBytes(String name, DocumentKind kind, Uint8List bytes) async {
    final receipt = await DocumentExportService(ref.read(storageChannelProvider)).save(name: name, kind: kind, bytes: bytes);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.l10n.t('savedVerified')} · ${receipt.byteCount} bytes')));
  }

  String _baseName() {
    final name = _nameController.text;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  void _showWarnings() {
    showDialog<void>(context: context, builder: (context) => AlertDialog(title: Text(context.l10n.t('compatibility')), content: Text([...?_session?.originalDocx?.warnings, context.l10n.t('docxEditNotice')].join('\n\n')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.t('close')))]));
  }
}

class _Base64ImageEmbedBuilder extends EmbedBuilder {
  const _Base64ImageEmbedBuilder();

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = embedContext.node.value.data as String;
    try {
      final bytes = base64Decode(data.contains(',') ? data.split(',').last : data);
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: Image.memory(bytes, fit: BoxFit.contain, semanticLabel: 'Document image'),
      );
    } on FormatException {
      return const Text('[Image unavailable]');
    }
  }
}
