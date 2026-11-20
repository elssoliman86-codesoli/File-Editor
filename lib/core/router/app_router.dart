import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/workspace_repository.dart';
import '../../features/about/about_page.dart';
import '../../features/document_editor/rich_editor_page.dart';
import '../../features/home/home_shell.dart';
import '../../features/pdf_editor/pdf_organizer_page.dart';
import '../../features/pdf_editor/pdf_tools_page.dart';
import '../../features/pdf_viewer/pdf_viewer_page.dart';
import '../../features/templates/templates_page.dart';
import '../../features/txt_editor/txt_editor_page.dart';
import '../providers/app_providers.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(path: '/home', builder: (context, state) => const HomeShell(initialIndex: 0)),
    GoRoute(path: '/documents', builder: (context, state) => const HomeShell(initialIndex: 1)),
    GoRoute(path: '/pdf-tools', builder: (context, state) => const HomeShell(initialIndex: 2)),
    GoRoute(path: '/settings', builder: (context, state) => const HomeShell(initialIndex: 3)),
    GoRoute(
      path: '/document/:id',
      builder: (context, state) => Consumer(
        builder: (context, ref, _) => DocumentOpener(
          id: state.pathParameters['id']!,
          repository: ref.read(workspaceProvider),
        ),
      ),
    ),
    GoRoute(path: '/templates', builder: (context, state) => const TemplatesPage()),
    GoRoute(path: '/pdf-organize/:id', builder: (context, state) => PdfOrganizerPage(recordId: state.pathParameters['id']!)),
    GoRoute(path: '/pdf-tool/:mode', builder: (context, state) => PdfToolWorkspace(mode: state.pathParameters['mode']!)),
    GoRoute(path: '/about', builder: (context, state) => const AboutPage()),
  ],
);

class DocumentOpener extends StatefulWidget {
  const DocumentOpener({required this.id, required this.repository, super.key});
  final String id;
  final WorkspaceRepository repository;

  @override
  State<DocumentOpener> createState() => _DocumentOpenerState();
}

class _DocumentOpenerState extends State<DocumentOpener> {
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final record = await widget.repository.byId(widget.id);
    if (!mounted) return;
    if (record == null) {
      Navigator.of(context).pop();
      return;
    }
    final page = switch (record.kind) {
      .docx => RichEditorPage(record: record),
      .pdf => PdfViewerPage(record: record),
      .txt => TxtEditorPage(record: record),
      _ => PdfToolWorkspace(mode: 'images', initialRecord: record),
    };
    await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

