import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/models/expense_category.dart';
import 'package:nubbill/models/expense_detail_model.dart';
import 'package:nubbill/models/settlement_model.dart';
import 'package:nubbill/services/auth_repository.dart';
import 'package:nubbill/services/expense_service.dart';
import 'package:nubbill/shared/app_icons.dart';
import 'package:nubbill/widgets/retry_error_state.dart';
import 'package:nubbill/widgets/settlement_detail_modal.dart';

class BillDetailsPage extends ConsumerWidget {
  final String expenseId;

  const BillDetailsPage({super.key, required this.expenseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseAsync = ref.watch(expenseDetailProvider(expenseId));
    final currentUserId = ref.watch(authUserIdProvider);

    return expenseAsync.when(
      loading: () => _buildScaffold(
        context,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _buildScaffold(
        context,
        body: RetryErrorState(
          error: error,
          onRetry: () => ref.invalidate(expenseDetailProvider(expenseId)),
        ),
      ),
      data: (detail) {
        if (detail == null) {
          return _buildScaffold(
            context,
            body: const Center(child: Text('ไม่พบข้อมูลบิล')),
          );
        }

        final canManageExpense =
            currentUserId != null && detail.createdBy == currentUserId;
        final hasLinkedSettlements = detail.settlements.any(
          (settlement) => settlement.status != 'rejected',
        );
        final memberNameById = {
          for (final split in detail.splits) split.memberId: split.displayName,
        };

        return _buildScaffold(
          context,
          actions: canManageExpense
              ? [
                  IconButton(
                    icon: const Icon(AppIcons.edit, color: Color(0xFF81CEF2)),
                    onPressed: () async {
                      if (hasLinkedSettlements) {
                        final shouldReverse = await _showReverseForEditDialog(
                          context,
                        );
                        if (!shouldReverse || !context.mounted) {
                          return;
                        }

                        try {
                          final result = await ref
                              .read(expenseServiceProvider)
                              .reverseSettlementsForEdit(
                                detail.id,
                                reason: 'expense_edit_requested_by_creator',
                              );

                          if (!context.mounted) return;
                          final reversedCount =
                              (result['reversed_settlement_count'] as num?)
                                  ?.toInt() ??
                              0;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                reversedCount > 0
                                    ? 'ย้อนรายการชำระ $reversedCount รายการแล้ว สามารถแก้ไขบิลได้'
                                    : 'ไม่พบรายการชำระที่ต้องย้อน',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          ref.invalidate(expenseDetailProvider(expenseId));
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('ไม่สามารถย้อนรายการชำระได้: $error'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                      }

                      final updated = await context.push<bool>(
                        '/add_expense',
                        extra: {
                          'tripId': detail.tripId,
                          'tripName': '',
                          'expenseId': detail.id,
                          'isEdit': true,
                        },
                      );

                      if (updated == true && context.mounted) {
                        ref.invalidate(expenseDetailProvider(expenseId));
                        context.pop(true);
                      }
                    },
                  ),
                ]
              : null,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(detail),
                const SizedBox(height: 14),
                if (detail.items.isNotEmpty) ...[
                  _buildItemsSection(detail, memberNameById),
                  const SizedBox(height: 14),
                ],
                _buildSplitSection(context, detail, currentUserId),
                if (canManageExpense) ...[
                  const SizedBox(height: 18),
                  _buildDeleteButton(context, ref, detail),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showReverseForEditDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (context) {
        return AlertDialog(
          title: const Text('ย้อนรายการชำระก่อนแก้ไขบิล?'),
          content: const Text(
            'ระบบจะย้อนสถานะการชำระเงินที่ผูกกับบิลนี้และบันทึกประวัติการย้อนรายการไว้ จากนั้นคุณจะแก้ไขบิลได้',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ย้อนแล้วแก้ไขต่อ'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Scaffold _buildScaffold(
    BuildContext context, {
    required Widget body,
    List<Widget>? actions,
  }) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(AppIcons.arrowBack, color: Color(0xFF141416)),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: const Text(
          'รายละเอียดบิล',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF141416),
          ),
        ),
        actions: actions,
      ),
      body: body,
    );
  }

  Widget _buildHeaderCard(ExpenseDetail detail) {
    final date = DateTime.tryParse(detail.expenseDate) ?? DateTime.now();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: detail.category.color,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              detail.category.icon,
              color: const Color(0xFF141416),
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            detail.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Color(0xFF141416),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatThaiDate(date),
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF7A8797),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${detail.amount.toStringAsFixed(2)}฿',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Color(0xFF141416),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _headerTag(
                detail.payer?.displayName ?? 'Unknown',
                AppIcons.person,
              ),
              _headerTag(
                detail.isItemized ? 'แยกรายการ' : 'หารเท่ากัน',
                detail.isItemized ? AppIcons.receipt : AppIcons.people,
              ),
              _headerTag(detail.category.label, detail.category.icon),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerTag(String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE3EAF2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF4E5D6E)),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4E5D6E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(
    ExpenseDetail detail,
    Map<String, String> memberNameById,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'รายการย่อย',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF141416),
            ),
          ),
          const SizedBox(height: 8),
          ...detail.items.map((item) {
            final sharedNames = item.sharedByMemberIds
                .map((id) => memberNameById[id] ?? 'สมาชิก')
                .toList();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE4EAF1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF141416),
                          ),
                        ),
                      ),
                      Text(
                        item.lineTotal.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF141416),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.amount.toStringAsFixed(2)} x ${item.quantity}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A8797),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (sharedNames.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: sharedNames
                          .map(
                            (name) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFDCE4EE),
                                ),
                              ),
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF4E5D6E),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSplitSection(
    BuildContext context,
    ExpenseDetail detail,
    String? currentUserId,
  ) {
    final isCurrentUserPrimaryPayer =
        currentUserId != null && detail.payer?.userId == currentUserId;
    final mySplits = currentUserId == null
        ? const <ExpenseDetailSplit>[]
        : detail.splits
              .where((split) => split.memberUserId == currentUserId)
              .toList();
    final mySplit = mySplits.isEmpty ? null : mySplits.first;
    final unpaidOthersTotal = detail.splits
        .where(
          (split) => split.memberId != detail.payerId && split.status != 'paid',
        )
        .fold<double>(0, (sum, split) => sum + split.amount);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ผู้หารบิล',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF141416),
            ),
          ),
          const SizedBox(height: 8),
          if (isCurrentUserPrimaryPayer &&
              detail.payers.isEmpty &&
              unpaidOthersTotal > 0) ...[
            _buildSplitSummaryBanner(
              label: 'คุณรอรับเงิน',
              amount: unpaidOthersTotal,
              textColor: const Color(0xFF1D4B64),
              backgroundColor: const Color(0xFFEAF6FD),
            ),
            const SizedBox(height: 8),
          ] else if (!isCurrentUserPrimaryPayer &&
              mySplit != null &&
              mySplit.status != 'paid') ...[
            _buildSplitSummaryBanner(
              label: 'คุณค้างจ่าย',
              amount: mySplit.amount,
              textColor: const Color(0xFFD32F2F),
              backgroundColor: const Color(0xFFFDEBEC),
            ),
            const SizedBox(height: 8),
          ],
          ...detail.splits.map((split) {
            final settlements = detail.settlementsForSplit(split.id);
            return _buildSplitRow(context, detail, split, settlements);
          }),
        ],
      ),
    );
  }

  Widget _buildSplitSummaryBanner({
    required String label,
    required double amount,
    required Color textColor,
    required Color backgroundColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)}฿',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitRow(
    BuildContext context,
    ExpenseDetail detail,
    ExpenseDetailSplit split,
    List<SettlementRecord> settlements,
  ) {
    final isPrimaryPayerShare =
        detail.payers.isEmpty && split.memberId == detail.payerId;
    final isPaid = split.status == 'paid' || isPrimaryPayerShare;
    final statusLabel = isPrimaryPayerShare
        ? 'คนจ่าย'
        : (isPaid ? 'จ่ายแล้ว' : 'ค้างจ่าย');
    final statusColor = isPrimaryPayerShare
        ? const Color(0xFF81CEF2)
        : (isPaid ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F));
    final statusBackground = isPrimaryPayerShare
        ? const Color(0xFFEAF6FD)
        : (isPaid ? const Color(0xFFE8F6EC) : const Color(0xFFFDEBEC));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4EAF1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFF81CEF2).withValues(alpha: 0.2),
            backgroundImage: split.memberAvatarUrl != null
                ? NetworkImage(split.memberAvatarUrl!)
                : null,
            child: split.memberAvatarUrl == null
                ? Text(
                    split.displayName.isNotEmpty
                        ? split.displayName.substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  split.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF141416),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${split.amount.toStringAsFixed(2)}฿',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5D6D80),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (settlements.isNotEmpty)
            IconButton(
              tooltip: 'ดูบันทึกการโอน',
              onPressed: () {
                showSettlementHistorySheet(
                  context,
                  settlements: settlements,
                  title: 'บันทึกการโอน',
                );
              },
              icon: const Icon(
                AppIcons.receipt,
                color: Color(0xFF81CEF2),
                size: 20,
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton(
    BuildContext context,
    WidgetRef ref,
    ExpenseDetail detail,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showDeleteDialog(context, ref, detail),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFEF5350),
          side: const BorderSide(color: Color(0xFFEF5350)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(AppIcons.delete),
        label: const Text(
          'ลบบิลนี้',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    ExpenseDetail detail,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'ลบบิลนี้?',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'คุณแน่ใจว่าต้องการลบบิล "${detail.description}"\nการกระทำนี้ไม่สามารถย้อนกลับได้',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await ref
                      .read(expenseServiceProvider)
                      .deleteExpense(detail.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ลบบิลเรียบร้อยแล้ว')),
                    );
                    context.pop(true);
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('ลบบิลไม่สำเร็จ: $error')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350),
                foregroundColor: Colors.white,
              ),
              child: const Text('ลบเลย'),
            ),
          ],
        );
      },
    );
  }

  String _formatThaiDate(DateTime date) {
    const thaiMonths = [
      '',
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];

    return '${date.day} ${thaiMonths[date.month]} ${date.year + 543}';
  }
}
