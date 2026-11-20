import 'package:flutter/material.dart';
import 'package:arabic_text/arabic_text.dart';

import '../../l10n/app_localizations.dart';

class SearchReplaceBar extends StatefulWidget {
  const SearchReplaceBar({
    required this.source,
    required this.onChanged,
    required this.onNavigate,
    required this.onReplaceAll,
    required this.onClose,
    this.allowRegex = true,
    super.key,
  });

  final String source;
  final ValueChanged<List<TextMatch>> onChanged;
  final ValueChanged<TextMatch> onNavigate;
  final ValueChanged<
    ({String query, String replacement, SearchOptions options})
  >
  onReplaceAll;
  final VoidCallback onClose;
  final bool allowRegex;

  @override
  State<SearchReplaceBar> createState() => _SearchReplaceBarState();
}

class _SearchReplaceBarState extends State<SearchReplaceBar> {
  final _query = TextEditingController();
  final _replacement = TextEditingController();
  final _engine = const TextSearchEngine();
  List<TextMatch> _matches = [];
  int _index = -1;
  bool _replace = false;
  bool _caseSensitive = false;
  bool _wholeWord = false;
  bool _regex = false;
  bool _normalize = true;

  SearchOptions get _options => SearchOptions(
    caseSensitive: _caseSensitive,
    wholeWord: _wholeWord,
    regex: _regex,
    normalizeArabic: _normalize,
  );

  @override
  void dispose() {
    _query.dispose();
    _replacement.dispose();
    super.dispose();
  }

  void _search() {
    try {
      setState(() {
        _matches = _engine.findAll(
          widget.source,
          _query.text,
          options: _options,
        );
        _index = _matches.isEmpty ? -1 : 0;
      });
      widget.onChanged(_matches);
      if (_index >= 0) widget.onNavigate(_matches[_index]);
    } on FormatException catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _move(int delta) {
    if (_matches.isEmpty) return;
    setState(() => _index = (_index + delta) % _matches.length);
    if (_index < 0) _index += _matches.length;
    widget.onNavigate(_matches[_index]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    onChanged: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: l10n.t('search'),
                      isDense: true,
                    ),
                  ),
                ),
                Text(
                  '${_matches.isEmpty ? 0 : _index + 1}/${_matches.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                IconButton(
                  onPressed: () => _move(-1),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
                IconButton(
                  onPressed: () => _move(1),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: [
                FilterChip(
                  label: Text(l10n.t('matchCase')),
                  selected: _caseSensitive,
                  onSelected: (v) {
                    _caseSensitive = v;
                    _search();
                  },
                ),
                FilterChip(
                  label: Text(l10n.t('wholeWord')),
                  selected: _wholeWord,
                  onSelected: (v) {
                    _wholeWord = v;
                    _search();
                  },
                ),
                if (widget.allowRegex)
                  FilterChip(
                    label: Text(l10n.t('regex')),
                    selected: _regex,
                    onSelected: (v) {
                      _regex = v;
                      _search();
                    },
                  ),
                FilterChip(
                  label: Text(l10n.t('normalizeArabic')),
                  selected: _normalize,
                  onSelected: (v) {
                    _normalize = v;
                    _search();
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.find_replace_rounded, size: 17),
                  label: Text(l10n.t('replace')),
                  onPressed: () => setState(() => _replace = !_replace),
                ),
              ],
            ),
            if (_replace)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replacement,
                      decoration: InputDecoration(hintText: l10n.t('replace')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => widget.onReplaceAll((
                      query: _query.text,
                      replacement: _replacement.text,
                      options: _options,
                    )),
                    child: Text(l10n.t('replaceAll')),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
