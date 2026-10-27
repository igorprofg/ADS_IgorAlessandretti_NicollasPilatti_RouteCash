import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/providers/sync_providers.dart';
import '../data/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(
    localRepository: ref.read(syncLocalRepositoryProvider),
    syncManager: ref.read(syncManagerProvider),
  ),
);
