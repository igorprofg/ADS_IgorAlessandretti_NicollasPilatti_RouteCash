import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/vehicle_repository.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepository();
});
