import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/earning_repository.dart';

final earningRepositoryProvider = Provider<EarningRepository>((ref) {
  return EarningRepository();
});
