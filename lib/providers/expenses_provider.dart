import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/models/expense_model.dart';
import 'package:nubbill/services/expense_repository.dart';

final expensesProvider = FutureProvider<List<Expense>>((ref) async {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getExpenses();
});
