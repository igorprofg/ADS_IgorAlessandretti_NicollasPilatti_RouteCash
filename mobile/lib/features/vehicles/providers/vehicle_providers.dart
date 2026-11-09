import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/providers/sync_providers.dart';
import '../data/vehicle_repository.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepository(
    localRepository: ref.read(syncLocalRepositoryProvider),
    syncManager: ref.read(syncManagerProvider),
  );
});
