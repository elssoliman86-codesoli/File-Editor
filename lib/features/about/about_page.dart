import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('about'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.edit_note_rounded, size: 72),
          Text(l10n.t('appName'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
          Text('${l10n.t('version')} 0.1.0+1', textAlign: TextAlign.center),
          const SizedBox(height: 28),
          Text(l10n.t('privacyPolicy'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(l10n.t('privacyBody'), style: const TextStyle(height: 1.8)),
          const SizedBox(height: 24),
          Text(l10n.t('limitations'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(l10n.t('docxEditNotice'), style: const TextStyle(height: 1.8)),
          const SizedBox(height: 14),
          Text(l10n.t('pdfEditNotice'), style: const TextStyle(height: 1.8)),
          const SizedBox(height: 14),
          const Text('TXT: UTF-8, UTF-16LE/BE, Windows-1256, ISO-8859-6 and Windows-1252. OCR, scanner, Track Changes, forms, redaction and digital signatures are not advertised as implemented.', style: TextStyle(height: 1.8)),
          const SizedBox(height: 24),
          const Text('Open-source components include Flutter, Flutter Quill, pdfrx/PDFium, dart_pdf, Archive, XML, Riverpod, SQLite and the fonts Tajawal and Noto Naskh Arabic. Their licenses are included in THIRD_PARTY_LICENSES.md.', style: TextStyle(height: 1.8)),
        ],
      ),
    );
  }
}
