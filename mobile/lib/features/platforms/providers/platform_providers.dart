import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/platform_repository.dart';

final platformRepositoryProvider = Provider<PlatformRepository>((ref) {
  return PlatformRepository();
});
