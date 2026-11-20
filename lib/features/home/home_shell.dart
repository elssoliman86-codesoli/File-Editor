import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../documents/documents_page.dart';
import '../onboarding/onboarding_page.dart';
import '../pdf_editor/pdf_tools_page.dart';
import '../settings/settings_page.dart';
import 'home_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({required this.initialIndex, super.key});
  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = [
      const HomePage(),
      const DocumentsPage(),
      const PdfToolsPage(),
      const SettingsPage(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: SafeArea(
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) {
            setState(() => _index = index);
            final path = [
              '/home',
              '/documents',
              '/pdf-tools',
              '/settings',
            ][index];
            if (GoRouterState.of(context).uri.path != path) context.go(path);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: l10n.t('home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.description_outlined),
              selectedIcon: const Icon(Icons.description_rounded),
              label: l10n.t('documents'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              selectedIcon: const Icon(Icons.picture_as_pdf_rounded),
              label: l10n.t('pdfTools'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings_rounded),
              label: l10n.t('settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingGate extends StatelessWidget {
  const OnboardingGate({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

// Onboarding is intentionally self-contained and does not block startup I/O.
const onboardingPage = OnboardingPage();
