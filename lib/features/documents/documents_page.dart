import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:document_core/document_core.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/document_tile.dart';
import '../../shared/widgets/empty_state.dart';
import 'document_actions.dart';

class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});

  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  String _query = '';
  DocumentKind? _filter;
  bool _favorites = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final documents = ref.watch(documentsProvider).where((record) {
      return record.name.toLowerCase().contains(_query.toLowerCase()) &&
          (_filter == null || record.kind == _filter) &&
          (!_favorites || record.favorite);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('documents')),
        actions: [
          IconButton(
            onPressed: () => importAndOpen(context, ref),
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: l10n.t('openFile'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: l10n.t('searchDocuments'),
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  _chip(
                    l10n.t('all'),
                    _filter == null && !_favorites,
                    () => setState(() {
                      _filter = null;
                      _favorites = false;
                    }),
                  ),
                  _chip(
                    l10n.t('favorites'),
                    _favorites,
                    () => setState(() => _favorites = !_favorites),
                    Icons.star_outline_rounded,
                  ),
                  _chip(
                    'Word',
                    _filter == DocumentKind.docx,
                    () => setState(
                      () => _filter = _filter == DocumentKind.docx
                          ? null
                          : DocumentKind.docx,
                    ),
                  ),
                  _chip(
                    'PDF',
                    _filter == DocumentKind.pdf,
                    () => setState(
                      () => _filter = _filter == DocumentKind.pdf
                          ? null
                          : DocumentKind.pdf,
                    ),
                  ),
                  _chip(
                    'TXT',
                    _filter == DocumentKind.txt,
                    () => setState(
                      () => _filter = _filter == DocumentKind.txt
                          ? null
                          : DocumentKind.txt,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: documents.isEmpty
                  ? EmptyState(
                      icon: Icons.manage_search_rounded,
                      title: l10n.t('emptyDocuments'),
                      message: l10n.t('emptyHint'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: documents.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final record = documents[index];
                        return DocumentTile(
                          record: record,
                          onOpen: () => context.push('/document/${record.id}'),
                          onFavorite: () => ref
                              .read(documentsProvider.notifier)
                              .toggleFavorite(record),
                          onDelete: () =>
                              confirmRemoveDocument(context, ref, record),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    String label,
    bool selected,
    VoidCallback onTap, [
    IconData? icon,
  ]) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: FilterChip(
        selected: selected,
        avatar: icon == null ? null : Icon(icon, size: 16),
        label: Text(label),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
