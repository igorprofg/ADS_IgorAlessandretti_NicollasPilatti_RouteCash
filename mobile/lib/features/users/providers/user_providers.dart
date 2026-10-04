import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});