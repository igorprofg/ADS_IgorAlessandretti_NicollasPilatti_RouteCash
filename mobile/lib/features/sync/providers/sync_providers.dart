import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync_local_repository.dart';
import '../data/sync_repository.dart';
import '../services/sync_auto_service.dart';
import '../services/sync_manager.dart';

final syncLocalRepositoryProvider = Provider<SyncLocalRepository>((ref) {
  return SyncLocalRepository();
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository();
});

final syncManagerProvider = Provider<SyncManager>((ref) {
  final localRepository = ref.read(syncLocalRepositoryProvider);

  final remoteRepository = ref.read(syncRepositoryProvider);

  return SyncManager(
    remoteRepository: remoteRepository,
    localRepository: localRepository,
  );
});

final syncAutoServiceProvider = Provider<SyncAutoService>((ref) {
  final service = SyncAutoService(
    syncManager: ref.read(syncManagerProvider),
    localRepository: ref.read(syncLocalRepositoryProvider),
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});
