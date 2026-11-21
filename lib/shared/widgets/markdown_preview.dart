import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../l10n/app_localizations.dart';

/// True when the text is mostly written in a right-to-left script.
bool looksRtl(String text) {
  final sample = text.length > 2000 ? text.substring(0, 2000) : text;
  final rtl = RegExp(r'[֐-ࣿיִ-﷿ﹰ-﻿]');
  final ltr = RegExp(r'[A-Za-z]');
  return rtl.allMatches(sample).length > ltr.allMatches(sample).length;
}

/// Renders Markdown (GitHub flavoured: tables, task lists, fenced code,
/// strikethrough, autolinks) as formatted content instead of raw text.
class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({
    required this.data,
    required this.rtl,
    this.fontSize = 17,
    super.key,
  });

  final String data;
  final bool rtl;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (data.trim().isEmpty) {
      return Center(child: Text(context.l10n.t('previewEmpty')));
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = TextStyle(
      fontFamily: 'NotoNaskhArabic',
      fontSize: fontSize,
      height: 1.7,
      color: scheme.onSurface,
    );
    final sheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: body,
      h1: body.copyWith(fontSize: fontSize * 1.9, fontWeight: FontWeight.w800),
      h2: body.copyWith(fontSize: fontSize * 1.55, fontWeight: FontWeight.w800),
      h3: body.copyWith(fontSize: fontSize * 1.3, fontWeight: FontWeight.w700),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: fontSize * .88,
        backgroundColor: scheme.surfaceContainerHighest,
        color: scheme.onSurface,
      ),
      codeblockDecoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      blockquoteDecoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
      ),
    );
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Markdown(
        data: data,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        extensionSet: md.ExtensionSet.gitHubFlavored,
        styleSheet: sheet,
        onTapLink: (text, href, title) => _copyLink(context, href),
        imageBuilder: _image,
      ),
    );
  }

  Widget _image(Uri uri, String? title, String? alt) {
    final label = alt == null || alt.isEmpty ? uri.toString() : alt;
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return _imagePlaceholder(label);
    }
    return Image.network(
      uri.toString(),
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _imagePlaceholder(label),
    );
  }

  Widget _imagePlaceholder(String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.image_not_supported_outlined, size: 18),
      const SizedBox(width: 6),
      Flexible(child: Text(label)),
    ],
  );

  Future<void> _copyLink(BuildContext context, String? href) async {
    if (href == null || href.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: href));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(href)));
    }
  }
}
