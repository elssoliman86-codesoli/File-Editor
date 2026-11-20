import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/document_record.dart';
import '../../data/platform/storage_channel.dart';
import '../../data/repositories/workspace_repository.dart';

final workspaceProvider = Provider<WorkspaceRepository>(
  (ref) => WorkspaceRepository(),
);
final storageChannelProvider = Provider<StorageChannel>(
  (ref) => const StorageChannel(),
);

final documentsProvider =
    NotifierProvider<DocumentsController, List<DocumentRecord>>(
      DocumentsController.new,
    );

class DocumentsController extends Notifier<List<DocumentRecord>> {
  @override
  List<DocumentRecord> build() {
    Future.microtask(refresh);
    return const [];
  }

  Future<void> refresh() async {
    state = await ref.read(workspaceProvider).list();
  }

  Future<void> remove(DocumentRecord record) async {
    await ref.read(workspaceProvider).remove(record);
    await refresh();
  }

  Future<void> toggleFavorite(DocumentRecord record) async {
    await ref.read(workspaceProvider).toggleFavorite(record);
    await refresh();
  }
}
