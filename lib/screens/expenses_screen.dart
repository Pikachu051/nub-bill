import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/services/auth_repository.dart';
import 'package:nubbill/services/trip_service.dart';
import 'package:nubbill/services/expense_service.dart';
import 'package:nubbill/widgets/retry_error_state.dart';
import 'package:nubbill/shared/providers/realtime_invalidator.dart';
import 'package:nubbill/shared/widgets/realtime_animated_list.dart';
import 'package:nubbill/shared/widgets/list_animations.dart';

/// Provider for all user expenses across all trips
final allExpensesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final userId = ref.watch(authUserIdProvider);
      if (userId == null) return [];

      // Watch wallet realtime to auto-refresh when expenses change anywhere.
      ref.watch(walletRealtimeProvider);

      final tripService = ref.read(tripServiceProvider);
      final expenseService = ref.read(expenseServiceProvider);

      // Get all trips
      final trips = await tripService.getTrips();

      // Fetch expenses for each trip
      final allExpenses = <Map<String, dynamic>>[];
      for (final trip in trips) {
        try {
          final expenses = await expenseService.getTripExpenses(trip.id);
          for (final expense in expenses) {
            // Add trip info to expense
            final expenseMap = expense as Map<String, dynamic>;
            expenseMap['trip_name'] = trip.name;
            expenseMap['trip_id'] = trip.id;
            allExpenses.add(expenseMap);
          }
        } catch (e) {
          // Skip trips with errors
        }
      }

      // Sort by date (newest first)
      allExpenses.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['expense_date'] ?? '') ?? DateTime(2000);
        final dateB =
            DateTime.tryParse(b['expense_date'] ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      return allExpenses;
    });

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(allExpensesProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'รายการค่าใช้จ่าย',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => RetryErrorState(
          error: err,
          onRetry: () => ref.invalidate(allExpensesProvider),
        ),
        data: (expenses) {
          if (expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.receipt, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'ยังไม่มีรายการค่าใช้จ่าย',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allExpensesProvider);
            },
            child: RealtimeAnimatedList<Map<String, dynamic>>(
              items: expenses,
              keyExtractor: (e) => e['id']?.toString() ?? '',
              padding: const EdgeInsets.all(16),
              itemBuilder: (ctx, expense, animation) =>
                  slideInBuilder(ctx, _ExpenseCard(expense: expense), animation),
              removedItemBuilder: (ctx, expense, animation) =>
                  slideOutBuilder(ctx, _ExpenseCard(expense: expense), animation),
            ),
          );
        },
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Map<String, dynamic> expense;

  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final description = expense['description'] ?? 'ไม่มีรายละเอียด';
    final amount = (expense['amount'] as num?)?.toDouble() ?? 0;
    final date =
        DateTime.tryParse(expense['expense_date'] ?? '') ?? DateTime.now();
    final tripName = expense['trip_name'] ?? '';

    // Determine status from splits if available
    String statusLabel = '';
    Color statusColor = Colors.grey;

    final splits = expense['splits'] as List<dynamic>?;
    if (splits != null && splits.isNotEmpty) {
      final unpaidSplits = splits.where((s) => s['status'] == 'unpaid').length;
      if (unpaidSplits == 0) {
        statusLabel = 'เคลียร์แล้ว';
        statusColor = Colors.green;
      } else {
        statusLabel = 'ค้าง $unpaidSplits คน';
        statusColor = Colors.orange;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF81CEF2).withValues(alpha: 0.1),
          child: const Icon(AppIcons.receipt, color: Color(0xFF81CEF2)),
        ),
        title: Text(
          description,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${_formatDate(date)} • $tripName'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '฿${amount.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (statusLabel.isNotEmpty)
              Text(
                statusLabel,
                style: TextStyle(fontSize: 12, color: statusColor),
              ),
          ],
        ),
        onTap: () {
          context.push('/bill_details', extra: expense);
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
