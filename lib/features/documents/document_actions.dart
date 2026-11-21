import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:document_core/document_core.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/settings/settings_controller.dart';
import '../../data/models/document_record.dart';
import '../../l10n/app_localizations.dart';

Future<void> showError(BuildContext context, Object error) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${context.l10n.t('errorOpen')}\n$error')),
  );
}

Future<void> importAndOpen(BuildContext context, WidgetRef ref) async {
  try {
    final records = await ref.read(workspaceProvider).importFiles();
    await ref.read(documentsProvider.notifier).refresh();
    if (records.isNotEmpty && context.mounted)
      await context.push('/document/${records.first.id}');
  } catch (error) {
    if (context.mounted) await showError(context, error);
  }
}

/// Shows the "new document" sheet and creates the chosen document.
///
/// The sheet only reports the choice. Creating and opening happen afterwards
/// with the caller's own [context], which stays mounted; the previous
/// implementation used the sheet's context after popping it, so the document
/// was created but never opened.
Future<void> showNewDocumentSheet(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final kind = await showModalBottomSheet<DocumentKind>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('newDocument'),
              style: Theme.of(sheetContext).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            _newTile(
              sheetContext,
              Icons.description_outlined,
              l10n.t('wordDocument'),
              '.docx',
              DocumentKind.docx,
            ),
            _newTile(
              sheetContext,
              Icons.notes_rounded,
              l10n.t('textDocument'),
              '.txt',
              DocumentKind.txt,
            ),
            _newTile(
              sheetContext,
              Icons.code_rounded,
              l10n.t('markdownDocument'),
              '.md',
              DocumentKind.markdown,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: Text(l10n.t('template')),
              subtitle: Text(l10n.t('selectTemplate')),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/templates');
              },
            ),
          ],
        ),
      ),
    ),
  );
  if (kind == null || !context.mounted) return;
  await createAndOpen(context, ref, kind);
}

/// Creates an empty document of [kind] and opens it in its editor.
Future<void> createAndOpen(
  BuildContext context,
  WidgetRef ref,
  DocumentKind kind,
) async {
  try {
    final l10n = context.l10n;
    final settings = ref.read(settingsProvider);
    final workspace = ref.read(workspaceProvider);
    final base = l10n.t('newDocumentName');
    final name = uniqueDocumentName(
      ref.read(documentsProvider),
      base,
      kind.defaultExtension,
    );
    final record = await workspace.create(
      kind: kind,
      name: name,
      text: kind == DocumentKind.markdown ? '# $base\n\n' : '',
      defaultRtl: settings.defaultRtl,
    );
    await ref.read(documentsProvider.notifier).refresh();
    if (context.mounted) await context.push('/document/${record.id}');
  } catch (error) {
    if (context.mounted) await showError(context, error);
  }
}

/// "Name.ext", then "Name (2).ext", "Name (3).ext", ... like Office does.
String uniqueDocumentName(
  List<DocumentRecord> existing,
  String base,
  String extension,
) {
  final taken = {for (final record in existing) record.name.toLowerCase()};
  var candidate = '$base.$extension';
  for (var n = 2; taken.contains(candidate.toLowerCase()); n++) {
    candidate = '$base ($n).$extension';
  }
  return candidate;
}

Widget _newTile(
  BuildContext sheetContext,
  IconData icon,
  String title,
  String extension,
  DocumentKind kind,
) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(extension),
    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
    onTap: () => Navigator.pop(sheetContext, kind),
  );
}

Future<void> confirmRemoveDocument(
  BuildContext context,
  WidgetRef ref,
  DocumentRecord record,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.t('confirmDelete')),
      content: Text(context.l10n.t('confirmDeleteBody')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(context.l10n.t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(context.l10n.t('delete')),
        ),
      ],
    ),
  );
  if (confirmed == true)
    await ref.read(documentsProvider.notifier).remove(record);
}
