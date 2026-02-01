import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nubbill/config/supabase_config.dart';
import 'package:nubbill/models/expense_model.dart';
import 'package:nubbill/services/auth_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(SupabaseConfig.client, ref);
});

class ExpenseRepository {
  final SupabaseClient _client;
  final Ref _ref;

  ExpenseRepository(this._client, this._ref);

  Future<List<Expense>> getExpenses() async {
    final user = _ref.read(authRepositoryProvider).currentUser;
    if (user == null) return [];

    try {
      // Assuming 'expenses' table exists
      final response = await _client
          .from('expenses')
          .select()
          .order('date', ascending: false);

      return (response as List).map((e) => Expense.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> createExpense({
    required String title,
    required double amount,
    String? groupId,
  }) async {
    final user = _ref.read(authRepositoryProvider).currentUser;
    if (user == null) throw Exception('User not logged in');

    await _client.from('expenses').insert({
      'title': title,
      'amount': amount,
      'payer_id': user.id,
      'group_id': groupId,
      'date': DateTime.now().toIso8601String(),
      'created_by': user.id,
    });
  }
}
