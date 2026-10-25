import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/journey_repository.dart';

final journeyRepositoryProvider = Provider<JourneyRepository>((ref) {
  return JourneyRepository();
});
