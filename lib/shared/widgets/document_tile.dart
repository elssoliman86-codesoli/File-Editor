import 'package:flutter/material.dart';
import 'package:document_core/document_core.dart';
import 'package:intl/intl.dart';

import '../../data/models/document_record.dart';
import '../../l10n/app_localizations.dart';

class DocumentTile extends StatelessWidget {
  const DocumentTile({
    required this.record,
    required this.onOpen,
    this.onFavorite,
    this.onDelete,
    this.compact = false,
    super.key,
  });

  final DocumentRecord record;
  final VoidCallback onOpen;
  final VoidCallback? onFavorite;
  final VoidCallback? onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (record.kind) {
      DocumentKind.pdf => const Color(0xFFFF6B6B),
      DocumentKind.docx => const Color(0xFF5C9DFF),
      DocumentKind.txt => const Color(0xFF2ECC8F),
      _ => const Color(0xFFFFB020),
    };
    final icon = switch (record.kind) {
      DocumentKind.pdf => Icons.picture_as_pdf_outlined,
      DocumentKind.docx => Icons.description_outlined,
      DocumentKind.txt => Icons.notes_rounded,
      _ => Icons.image_outlined,
    };
    final date = DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .format(DateTime.fromMillisecondsSinceEpoch(record.lastOpened));
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: compact ? 44 : 52,
                height: compact ? 52 : 62,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: compact ? 23 : 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            date,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (record.dirty) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFB020),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              context.l10n.t('unsaved'),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFFFB020),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (onFavorite != null)
                IconButton(
                  tooltip: record.favorite
                      ? context.l10n.t('unfavorite')
                      : context.l10n.t('favorite'),
                  onPressed: onFavorite,
                  icon: Icon(
                    record.favorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: record.favorite ? const Color(0xFFFFB020) : null,
                  ),
                ),
              if (onDelete != null)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') onDelete!();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(context.l10n.t('removeRecent')),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
