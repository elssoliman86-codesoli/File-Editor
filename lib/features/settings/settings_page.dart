import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../../l10n/app_localizations.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    void update(AppSettings next) => controller.update(next);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _section(context, l10n.t('appearance')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(l10n.t('appearance')),
                  trailing: DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.t('darkMode'))),
                      DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.t('lightMode'))),
                      DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.t('systemMode'))),
                    ],
                    onChanged: (value) { if (value != null) update(settings.copyWith(themeMode: value)); },
                  ),
                ),
                SwitchListTile(title: Text(l10n.t('amoled')), value: settings.amoled, onChanged: (v) => update(settings.copyWith(amoled: v))),
                SwitchListTile(title: Text(l10n.t('highContrast')), value: settings.highContrast, onChanged: (v) => update(settings.copyWith(highContrast: v))),
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(l10n.t('language')),
                  trailing: SegmentedButton<String>(
                    segments: const [ButtonSegment(value: 'ar', label: Text('العربية')), ButtonSegment(value: 'en', label: Text('English'))],
                    selected: {settings.locale.languageCode},
                    onSelectionChanged: (values) => update(settings.copyWith(locale: Locale(values.first))),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _section(context, l10n.t('editor')),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text(l10n.t('fontSize')),
                  subtitle: Slider(value: settings.editorFontSize, min: 14, max: 30, divisions: 16, label: settings.editorFontSize.round().toString(), onChanged: (v) => update(settings.copyWith(editorFontSize: v))),
                  trailing: Text(settings.editorFontSize.round().toString()),
                ),
                SwitchListTile(title: Text(l10n.t('defaultRtl')), value: settings.defaultRtl, onChanged: (v) => update(settings.copyWith(defaultRtl: v))),
                ListTile(
                  title: Text(l10n.t('autosave')),
                  subtitle: Text('${settings.autosaveSeconds} ${l10n.t('lines')}'),
                  trailing: DropdownButton<int>(
                    value: settings.autosaveSeconds,
                    items: const [5, 12, 30, 60].map((v) => DropdownMenuItem(value: v, child: Text('$v s'))).toList(),
                    onChanged: (v) { if (v != null) update(settings.copyWith(autosaveSeconds: v)); },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _section(context, l10n.t('about')),
          Card(
            child: Column(
              children: [
                ListTile(leading: const Icon(Icons.info_outline_rounded), title: Text(l10n.t('about')), subtitle: const Text('Midad 0.1.0'), onTap: () => context.push('/about')),
                ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: Text(l10n.t('privacyPolicy')), onTap: () => context.push('/about')),
                ListTile(leading: const Icon(Icons.rule_rounded), title: Text(l10n.t('limitations')), onTap: () => context.push('/about')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    return Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 10), child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)));
  }
}
