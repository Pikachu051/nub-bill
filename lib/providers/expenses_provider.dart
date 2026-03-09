import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/models/expense_model.dart';
import 'package:nubbill/services/auth_repository.dart';
import 'package:nubbill/services/expense_repository.dart';

final expensesProvider = FutureProvider.autoDispose<List<Expense>>((ref) async {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) return [];

  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getExpenses();
});
