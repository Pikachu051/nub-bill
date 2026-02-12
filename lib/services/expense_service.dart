import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/config/api_config.dart';
import 'package:nubbill/models/expense_model.dart';
import 'package:nubbill/models/expense_detail_model.dart';

/// Provider for ExpenseService
final expenseServiceProvider = Provider<ExpenseService>((ref) {
  return ExpenseService(ApiClient());
});

/// Provider for expenses in a specific trip (typed)
final tripExpensesProvider = FutureProvider.family<List<Expense>, String>((
  ref,
  tripId,
) async {
  final service = ref.read(expenseServiceProvider);
  return service.getTripExpenses(tripId);
});

/// Provider for a specific expense detail (typed)
final expenseDetailProvider = FutureProvider.family<ExpenseDetail?, String>((
  ref,
  expenseId,
) async {
  final service = ref.read(expenseServiceProvider);
  return service.getExpenseDetail(expenseId);
});

/// Service for Expense API calls
class ExpenseService {
  final ApiClient _client;

  ExpenseService(this._client);

  /// GET /api/trips/:id/expenses - List expenses for a trip
  Future<List<Expense>> getTripExpenses(String tripId) async {
    final response = await _client.get('/trips/$tripId/expenses');

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to load expenses');
    }

    final data = response.data as List<dynamic>;
    return data
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/trips/:id/expenses - Create expense
  Future<Map<String, dynamic>> createExpense({
    required String tripId,
    required String description,
    required double amount,
    required String splitType,
    String? payerMemberId,
    DateTime? expenseDate,
    double? serviceChargePercent,
    double? vatPercent,
    List<String>? splitMemberIds,
    List<Map<String, dynamic>>? splits,
    List<Map<String, dynamic>>? items,
  }) async {
    final body = <String, dynamic>{
      'description': description,
      'amount': amount,
      'split_type': splitType,
    };

    if (payerMemberId != null) body['payer_member_id'] = payerMemberId;
    if (expenseDate != null)
      body['expense_date'] = expenseDate.toIso8601String().split('T')[0];
    if (serviceChargePercent != null)
      body['service_charge_percent'] = serviceChargePercent;
    if (vatPercent != null) body['vat_percent'] = vatPercent;
    if (splitMemberIds != null) body['split_member_ids'] = splitMemberIds;
    if (splits != null) body['splits'] = splits;
    if (items != null) body['items'] = items;

    final response = await _client.post('/trips/$tripId/expenses', body: body);

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to create expense');
    }

    return response.data as Map<String, dynamic>;
  }

  /// GET /api/expenses/:id - Get expense details (typed)
  Future<ExpenseDetail> getExpenseDetail(String expenseId) async {
    final response = await _client.get('/expenses/$expenseId');

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to load expense details');
    }

    return ExpenseDetail.fromJson(response.data as Map<String, dynamic>);
  }

  /// PATCH /api/expenses/:id - Update expense
  Future<Map<String, dynamic>> updateExpense(
    String expenseId, {
    String? description,
    double? amount,
    DateTime? expenseDate,
  }) async {
    final body = <String, dynamic>{};

    if (description != null) body['description'] = description;
    if (amount != null) body['amount'] = amount;
    if (expenseDate != null)
      body['expense_date'] = expenseDate.toIso8601String().split('T')[0];

    final response = await _client.patch('/expenses/$expenseId', body: body);

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to update expense');
    }

    return response.data as Map<String, dynamic>;
  }

  /// DELETE /api/expenses/:id - Delete expense
  Future<void> deleteExpense(String expenseId) async {
    final response = await _client.delete('/expenses/$expenseId');

    if (!response.isSuccess) {
      throw Exception(response.error ?? 'Failed to delete expense');
    }
  }
}
