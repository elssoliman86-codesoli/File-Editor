import 'dart:async';
import 'dart:typed_data';

import 'package:arabic_text/arabic_text.dart';
import 'package:document_core/document_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:txt_engine/txt_engine.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/document_export_service.dart';
import '../../data/models/document_record.dart';
import '../../data/models/editor_session.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/markdown_preview.dart';
import '../../shared/widgets/search_replace_bar.dart';

class TxtEditorPage extends ConsumerStatefulWidget {
  const TxtEditorPage({required this.record, super.key});
  final DocumentRecord record;

  @override
  ConsumerState<TxtEditorPage> createState() => _TxtEditorPageState();
}

class _TxtEditorPageState extends ConsumerState<TxtEditorPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _nameController = TextEditingController();
  final _history = _TextHistory();
  EditorSession? _session;
  Timer? _autosave;
  Timer? _statsTimer;
  Timer? _renameTimer;
  final _stats = ValueNotifier<TextStatistics>(TextStatistics.from(''));
  bool _preview = false;
  Object? _loadError;
  String _encoding = 'utf-8';
  String _eol = '\n';
  bool _bom = false;
  bool _rtl = true;
  bool _wrap = true;
  bool _search = false;
  bool _dirty = false;
  bool _saving = false;
  int _historyVersion = 0;

  bool get _isMarkdown => widget.record.kind == DocumentKind.markdown;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.record.name;
    _load();
  }

  Future<void> _load() async {
    try {
      final session = await ref
          .read(workspaceProvider)
          .loadSession(widget.record);
      if (!mounted) return;
      _session = session;
      _textController.text = session.text;
      _encoding = session.record.encoding;
      _eol = session.record.eol;
      _history.reset(session.text);
      _stats.value = TextStatistics.from(session.text);
      // An existing Markdown file opens rendered; a brand-new one opens for editing.
      _preview =
          _isMarkdown && !widget.record.dirty && session.text.trim().isNotEmpty;
      _textController.addListener(_onEdit);
      setState(() {});
      _schedule();
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  void _onEdit() {
    if (!_dirty) setState(() => _dirty = true);
    _historyVersion++;
    // Statistics are recomputed once typing pauses instead of on every key.
    _statsTimer?.cancel();
    _statsTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _stats.value = TextStatistics.from(_textController.text);
    });
    if (_historyVersion % 8 == 0) _history.push(_textController.text);
    _schedule();
  }

  void _schedule() {
    _autosave?.cancel();
    _autosave = Timer(const Duration(seconds: 5), _saveRecovery);
  }

  Future<void> _saveRecovery() async {
    if (_session == null) return;
    await ref
        .read(workspaceProvider)
        .saveRecovery(
          _session!.record,
          text: _textController.text,
          encoding: _encoding,
          eol: _eol,
        );
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _statsTimer?.cancel();
    if (_renameTimer?.isActive ?? false) {
      _renameTimer!.cancel();
      unawaited(
        ref.read(workspaceProvider).rename(widget.record, _nameController.text),
      );
    }
    if (_session != null) unawaited(_saveRecovery());
    _textController.dispose();
    _scrollController.dispose();
    _nameController.dispose();
    _stats.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loadError != null)
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('${l10n.t('errorOpen')}\n$_loadError')),
      );
    if (_session == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _saveRecovery();
        if (context.mounted) Navigator.pop(context);
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              _saveTxt,
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
              setState(() => _search = true),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              titleSpacing: 0,
              title: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  filled: false,
                  isDense: true,
                ),
                style: const TextStyle(fontWeight: FontWeight.w700),
                onChanged: (_) {
                  _renameTimer?.cancel();
                  _renameTimer = Timer(
                    const Duration(milliseconds: 600),
                    () => ref
                        .read(workspaceProvider)
                        .rename(widget.record, _nameController.text),
                  );
                },
              ),
              actions: [
                if (!_preview) ...[
                  IconButton(
                    tooltip: l10n.t('undo'),
                    onPressed: _history.canUndo ? _undo : null,
                    icon: const Icon(Icons.undo_rounded),
                  ),
                  IconButton(
                    tooltip: l10n.t('redo'),
                    onPressed: _history.canRedo ? _redo : null,
                    icon: const Icon(Icons.redo_rounded),
                  ),
                  IconButton(
                    tooltip: l10n.t('search'),
                    onPressed: () => setState(() => _search = !_search),
                    icon: const Icon(Icons.search_rounded),
                  ),
                ],
                IconButton(
                  tooltip: l10n.t('save'),
                  onPressed: _saving ? null : _saveTxt,
                  icon: const Icon(Icons.save_outlined),
                ),
                PopupMenuButton<String>(
                  onSelected: _menu,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'pdf',
                      child: Text(l10n.t('exportPdf')),
                    ),
                    PopupMenuItem(value: 'share', child: Text(l10n.t('share'))),
                    PopupMenuItem(value: 'print', child: Text(l10n.t('print'))),
                    PopupMenuItem(
                      value: 'rtl',
                      child: Text(_rtl ? l10n.t('ltr') : l10n.t('rtl')),
                    ),
                    PopupMenuItem(
                      value: 'wrap',
                      child: Text('Word wrap: ${_wrap ? 'ON' : 'OFF'}'),
                    ),
                  ],
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  if (_isMarkdown)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: false,
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(l10n.t('edit')),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: const Icon(Icons.visibility_outlined),
                            label: Text(l10n.t('preview')),
                          ),
                        ],
                        selected: {_preview},
                        onSelectionChanged: (value) =>
                            setState(() => _preview = value.first),
                      ),
                    ),
                  if (_search && !_preview)
                    SearchReplaceBar(
                      source: _textController.text,
                      onChanged: (_) {},
                      onNavigate: (match) =>
                          _textController.selection = TextSelection(
                            baseOffset: match.start,
                            extentOffset: match.end,
                          ),
                      onReplaceAll: (request) {
                        final result = const TextSearchEngine().replaceAll(
                          _textController.text,
                          request.query,
                          request.replacement,
                          options: request.options,
                        );
                        _setText(result);
                      },
                      onClose: () => setState(() => _search = false),
                    ),
                  Expanded(
                    child: Container(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF0D1424)
                          : Colors.white,
                      child: _preview
                          ? MarkdownPreview(
                              data: _textController.text,
                              rtl: _rtl,
                            )
                          : _wrap
                          ? TextField(
                              controller: _textController,
                              scrollController: _scrollController,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              textDirection: _rtl
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              textAlign: _rtl
                                  ? TextAlign.right
                                  : TextAlign.left,
                              keyboardType: TextInputType.multiline,
                              style: TextStyle(
                                fontFamily: 'NotoNaskhArabic',
                                fontSize: 18,
                                height: 1.7,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.all(20),
                                border: InputBorder.none,
                                filled: false,
                                hintText: l10n.t('notes'),
                                hintTextDirection: _rtl
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 1600,
                                ),
                                child: TextField(
                                  controller: _textController,
                                  scrollController: _scrollController,
                                  maxLines: null,
                                  textAlignVertical: TextAlignVertical.top,
                                  textDirection: _rtl
                                      ? TextDirection.rtl
                                      : TextDirection.ltr,
                                  textAlign: _rtl
                                      ? TextAlign.right
                                      : TextAlign.left,
                                  keyboardType: TextInputType.multiline,
                                  style: const TextStyle(
                                    fontFamily: 'NotoNaskhArabic',
                                    fontSize: 18,
                                    height: 1.7,
                                  ),
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.all(20),
                                    border: InputBorder.none,
                                    filled: false,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  ValueListenableBuilder<TextStatistics>(
                    valueListenable: _stats,
                    builder: (context, stats, _) => _StatusBar(
                      stats: stats,
                      encoding: _encoding,
                      eol: _eol,
                      onEncoding: _changeEncoding,
                      onEol: (value) => setState(() => _eol = value),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setText(String value) {
    _history.push(_textController.text);
    _textController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() => _dirty = true);
  }

  void _undo() {
    final value = _history.undo(_textController.text);
    if (value != null) _setTextFromHistory(value);
  }

  void _redo() {
    final value = _history.redo(_textController.text);
    if (value != null) _setTextFromHistory(value);
  }

  void _setTextFromHistory(String value) {
    _textController.text = value;
    setState(() {});
  }

  Future<void> _changeEncoding(String encoding) async {
    setState(() => _encoding = encoding);
    await _saveRecovery();
  }

  Future<Uint8List> _bytes() => ref
      .read(workspaceProvider)
      .buildDocument(
        _session!,
        text: _textController.text,
        encoding: _encoding,
        eol: _eol,
        bom: _bom,
      );

  Future<void> _saveTxt() async {
    setState(() => _saving = true);
    try {
      final bytes = await _bytes();
      final decoded = const TextCodec().decode(
        bytes,
        requestedEncoding: _encoding,
      );
      if (decoded.text.replaceAll('\r\n', '\n').replaceAll('\r', '\n') !=
          _textController.text
              .replaceAll('\r\n', '\n')
              .replaceAll('\r', '\n')) {
        throw const FormatException('Text read-back differs from the editor.');
      }
      await DocumentExportService(ref.read(storageChannelProvider)).save(
        name: _nameController.text,
        kind: widget.record.kind,
        bytes: bytes,
      );
      await ref.read(workspaceProvider).markExported(widget.record, bytes);
      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('savedVerified'))),
        );
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.t('errorSave')}\n$error')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _menu(String action) async {
    final exporter = DocumentExportService(ref.read(storageChannelProvider));
    if (action == 'rtl') {
      setState(() => _rtl = !_rtl);
      return;
    }
    if (action == 'wrap') {
      setState(() => _wrap = !_wrap);
      return;
    }
    try {
      if (action == 'pdf') {
        final bytes = await exporter.textToPdf(
          title: _nameController.text,
          text: _textController.text,
          rtl: _rtl,
        );
        await exporter.save(
          name:
              '${_nameController.text.replaceAll(RegExp(r'\.(txt|md)$'), '')}.pdf',
          kind: DocumentKind.pdf,
          bytes: bytes,
        );
      } else if (action == 'share') {
        await exporter.share(
          _nameController.text,
          await _bytes(),
          widget.record.kind.mimeType,
        );
      } else if (action == 'print') {
        await exporter.printText(
          title: _nameController.text,
          text: _textController.text,
          rtl: _rtl,
        );
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.stats,
    required this.encoding,
    required this.eol,
    required this.onEncoding,
    required this.onEol,
  });
  final TextStatistics stats;
  final String encoding;
  final String eol;
  final ValueChanged<String> onEncoding;
  final ValueChanged<String> onEol;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            Center(
              child: Text(
                '${stats.lines} ${context.l10n.t('lines')} · ${stats.words} ${context.l10n.t('words')} · ${stats.characters} ${context.l10n.t('characters')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 18),
            DropdownButton<String>(
              value: encoding,
              underline: const SizedBox(),
              items: const [
                'utf-8',
                'utf-16le',
                'utf-16be',
                'windows-1256',
                'iso-8859-6',
                'windows-1252',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                if (v != null) onEncoding(v);
              },
            ),
            const SizedBox(width: 18),
            DropdownButton<String>(
              value: eol,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: '\n', child: Text('LF')),
                DropdownMenuItem(value: '\r\n', child: Text('CRLF')),
                DropdownMenuItem(value: '\r', child: Text('CR')),
              ],
              onChanged: (v) {
                if (v != null) onEol(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TextHistory {
  final List<String> _undo = [];
  final List<String> _redo = [];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  void reset(String text) {
    _undo
      ..clear()
      ..add(text);
    _redo.clear();
  }

  void push(String text) {
    if (_undo.isEmpty || _undo.last != text) _undo.add(text);
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  String? undo(String current) {
    if (_undo.length < 2) return null;
    _redo.add(current);
    _undo.removeLast();
    return _undo.last;
  }

  String? redo(String current) {
    if (_redo.isEmpty) return null;
    _undo.add(current);
    return _redo.removeLast();
  }
}
