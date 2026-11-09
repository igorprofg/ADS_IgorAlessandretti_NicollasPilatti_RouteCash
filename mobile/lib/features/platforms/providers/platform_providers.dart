import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/providers/sync_providers.dart';
import '../data/platform_repository.dart';

final platformRepositoryProvider = Provider<PlatformRepository>((ref) {
  return PlatformRepository(
    localRepository: ref.read(syncLocalRepositoryProvider),
    syncManager: ref.read(syncManagerProvider),
  );
});
