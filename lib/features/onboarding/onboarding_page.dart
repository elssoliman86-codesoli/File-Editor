import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/theme/app_palette.dart';
import '../../l10n/app_localizations.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final settings = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).update(settings.copyWith(onboardingDone: true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      (Icons.shield_outlined, l10n.t('privacy'), l10n.t('privacyBody')),
      (Icons.save_outlined, l10n.t('safeSaving'), l10n.t('safeSavingBody')),
      (Icons.translate_rounded, l10n.t('arabicFirst'), l10n.t('arabicFirstBody')),
    ];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppPalette.navy2, AppPalette.deepNavy],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(onPressed: _finish, child: Text(l10n.t('skip'))),
                ),
                const Spacer(),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppPalette.electricBlue, AppPalette.cyan]),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 42),
                ),
                const SizedBox(height: 24),
                Text(l10n.t('appName'), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(l10n.t('appTagline'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppPalette.textSecondary)),
                const SizedBox(height: 40),
                SizedBox(
                  height: 250,
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: items.length,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Column(
                        children: [
                          Icon(item.$1, size: 48, color: AppPalette.cyan),
                          const SizedBox(height: 20),
                          Text(item.$2, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 16),
                          Text(item.$3, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.8, color: AppPalette.textSecondary)),
                        ],
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(items.length, (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    width: index == _index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(color: index == _index ? AppPalette.cyan : Colors.white24, borderRadius: BorderRadius.circular(8)),
                  )),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (_index == items.length - 1) {
                        _finish();
                      } else {
                        _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                      }
                    },
                    child: Text(_index == items.length - 1 ? l10n.t('start') : l10n.t('next')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
