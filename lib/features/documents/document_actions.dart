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

Future<void> showNewDocumentSheet(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  await showModalBottomSheet<void>(
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
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            _newTile(
              sheetContext,
              ref,
              Icons.description_outlined,
              l10n.t('wordDocument'),
              DocumentKind.docx,
            ),
            _newTile(
              sheetContext,
              ref,
              Icons.notes_rounded,
              l10n.t('textDocument'),
              DocumentKind.txt,
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
}

Widget _newTile(
  BuildContext context,
  WidgetRef ref,
  IconData icon,
  String title,
  DocumentKind kind,
) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
    onTap: () async {
      Navigator.pop(context);
      final settings = ref.read(settingsProvider);
      final record = await ref
          .read(workspaceProvider)
          .create(
            kind: kind,
            name: kind == DocumentKind.docx
                ? 'مستند جديد.docx'
                : 'مستند جديد.txt',
            defaultRtl: settings.defaultRtl,
          );
      await ref.read(documentsProvider.notifier).refresh();
      if (context.mounted) await context.push('/document/${record.id}');
    },
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
