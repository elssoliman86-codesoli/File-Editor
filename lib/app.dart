import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' as mui;

import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/services/external_document_service.dart';
import 'features/onboarding/onboarding_page.dart';
import 'core/settings/settings_controller.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

class MidadApp extends ConsumerWidget {
  const MidadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    ref.watch(externalDocumentServiceProvider);
    return MaterialApp.router(
      title: 'مِداد',
      debugShowCheckedModeBanner: false,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
        mui.GlobalMaterialLocalizations.delegate,
        mui.GlobalWidgetsLocalizations.delegate,
      ],
      theme: AppTheme.light(settings.highContrast),
      darkTheme: AppTheme.dark(settings.amoled, settings.highContrast),
      themeMode: settings.themeMode,
      routerConfig: appRouter,
      builder: (context, child) {
        return settings.onboardingDone ? child ?? const SizedBox.shrink() : const OnboardingPage();
      },
    );
  }
}
