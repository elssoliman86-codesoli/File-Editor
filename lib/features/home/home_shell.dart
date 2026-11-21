import 'package:flutter/material.dart';
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
  // Tabs are built the first time they are opened and then kept alive, so the
  // shell no longer constructs all four pages (and their providers) up front.
  late final Set<int> _visited = {widget.initialIndex};

  Widget _pageFor(int index) => switch (index) {
    0 => const HomePage(),
    1 => const DocumentsPage(),
    2 => const PdfToolsPage(),
    _ => const SettingsPage(),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < 4; i++)
            if (_visited.contains(i)) _pageFor(i) else const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() {
            _index = index;
            _visited.add(index);
          }),
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
