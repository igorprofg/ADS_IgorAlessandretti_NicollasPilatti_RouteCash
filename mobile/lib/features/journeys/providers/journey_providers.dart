import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/providers/sync_providers.dart';
import '../data/journey_repository.dart';

final journeyRepositoryProvider = Provider<JourneyRepository>((ref) {
  return JourneyRepository(
    localRepository: ref.read(syncLocalRepositoryProvider),
    syncManager: ref.read(syncManagerProvider),
  );
});
