import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/indicators_repository.dart';

final indicatorsRepositoryProvider = Provider<IndicatorsRepository>((ref) {
  return IndicatorsRepository();
});
