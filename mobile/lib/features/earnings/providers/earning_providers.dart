import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/providers/sync_providers.dart';
import '../data/earning_repository.dart';

final earningRepositoryProvider = Provider<EarningRepository>(
  (ref) => EarningRepository(
    localRepository: ref.read(syncLocalRepositoryProvider),
    syncManager: ref.read(syncManagerProvider),
  ),
);
