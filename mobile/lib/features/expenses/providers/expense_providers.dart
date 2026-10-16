import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/expense_category_repository.dart';
import '../data/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

final expenseCategoryRepositoryProvider = Provider<ExpenseCategoryRepository>((
  ref,
) {
  return ExpenseCategoryRepository();
});
