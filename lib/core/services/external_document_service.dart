import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/workspace_repository.dart';
import '../providers/app_providers.dart';
import '../router/app_router.dart';

final externalDocumentServiceProvider = Provider<ExternalDocumentService>((ref) {
  final service = ExternalDocumentService(ref);
  unawaited(service.initialize());
  ref.onDispose(service.dispose);
  return service;
});

class ExternalDocumentService {
  ExternalDocumentService(this._ref);
  final Ref _ref;
  static const _channel = MethodChannel('com.elssoliman.midad/storage');

  Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler(_handle);
    final initial = await _channel.invokeMethod<Map<Object?, Object?>>('getInitialDocument');
    await _open(initial);
    if (initial != null) await _channel.invokeMethod<void>('consumeInitialDocument');
  }

  Future<void> _handle(MethodCall call) async {
    if (call.method == 'onDocumentIntent') await _open(call.arguments as Map<Object?, Object?>?);
  }

  Future<void> _open(Map<Object?, Object?>? payload) async {
    if (payload == null) return;
    final path = payload['path'] as String?;
    if (path == null) return;
    final file = File(path);
    try {
      final record = await _ref.read(workspaceProvider).importBytes(
        payload['name'] as String? ?? 'shared-document',
        await file.readAsBytes(),
        sourceUri: payload['uri'] as String?,
      );
      await _ref.read(documentsProvider.notifier).refresh();
      appRouter.go('/document/${record.id}');
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  void dispose() {
    if (Platform.isAndroid) _channel.setMethodCallHandler(null);
  }
}
