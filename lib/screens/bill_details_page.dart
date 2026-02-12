import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/services/expense_service.dart';
import 'package:nubbill/models/expense_model.dart';
import 'package:nubbill/models/expense_detail_model.dart';

class BillDetailsPage extends ConsumerWidget {
  final String expenseId;

  const BillDetailsPage({super.key, required this.expenseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseAsync = ref.watch(expenseDetailProvider(expenseId));

    return expenseAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(child: Text('เกิดข้อผิดพลาด: $err')),
      ),
      data: (detail) {
        if (detail == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('ไม่พบข้อมูลบิล')),
          );
        }

        return _buildContent(context, ref, detail);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ExpenseDetail detail,
  ) {
    final date = DateTime.tryParse(detail.expenseDate) ?? DateTime.now();

    // Reuse category heuristics from Expense model
    final tempExpense = Expense(
      id: detail.id,
      tripId: detail.tripId,
      payerId: detail.payerId,
      amount: detail.amount,
      description: detail.description,
      expenseDate: detail.expenseDate,
      createdBy: detail.createdBy,
      createdAt: detail.createdAt,
      updatedAt: detail.updatedAt,
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF81CEF2)),
            onPressed: () {
              // Navigate to edit mode
              context.push(
                '/add_expense',
                extra: {
                  'tripId': detail.tripId,
                  'expenseId': detail.id,
                  'isEdit': true,
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Bill card
            _buildBillCard(tempExpense, detail, date),
            const SizedBox(height: 24),
            // Section: "รายการแบ่งจ่าย"
            _buildSectionTitle('รายการแบ่งจ่าย'),
            const SizedBox(height: 12),
            // Participant list
            ...detail.splits.map((split) => _buildParticipantCard(split)),
            const SizedBox(height: 24),
            // Delete button
            _buildDeleteButton(context, ref, detail),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBillCard(
    Expense tempExpense,
    ExpenseDetail detail,
    DateTime date,
  ) {
    final thaiMonths = [
      '',
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    final thaiYear = date.year + 543;
    final dateText = '${date.day} ${thaiMonths[date.month]} $thaiYear';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Category icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: tempExpense.categoryColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              tempExpense.categoryIcon,
              size: 28,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          // Title
          Text(
            detail.description,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // Date
          Text(
            dateText,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          // Total amount
          Text(
            '${detail.amount.toStringAsFixed(2)}฿',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF81CEF2),
            ),
          ),
          const SizedBox(height: 12),
          // Payer info
          if (detail.payer != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(
                    0xFF81CEF2,
                  ).withValues(alpha: 0.2),
                  backgroundImage: detail.payer!.avatarUrl != null
                      ? NetworkImage(detail.payer!.avatarUrl!)
                      : null,
                  child: detail.payer!.avatarUrl == null
                      ? Text(
                          detail.payer!.displayName.isNotEmpty
                              ? detail.payer!.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 12),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  'จ่ายโดย ${detail.payer!.displayName}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          const SizedBox(height: 8),
          // Split type label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF81CEF2).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getSplitTypeLabel(detail.splitType),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF81CEF2),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSplitTypeLabel(String splitType) {
    switch (splitType) {
      case 'equal':
        return 'แบ่งเท่ากัน';
      case 'exact':
        return 'แบ่งตามจำนวนเงิน';
      case 'percent':
        return 'แบ่งตามเปอร์เซ็นต์';
      case 'itemized':
        return 'แบ่งตามรายการ';
      default:
        return 'แบ่งเท่ากัน';
    }
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildParticipantCard(ExpenseDetailSplit split) {
    final isPaid = split.status == 'paid';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF81CEF2).withValues(alpha: 0.2),
              backgroundImage: split.memberAvatarUrl != null
                  ? NetworkImage(split.memberAvatarUrl!)
                  : null,
              child: split.memberAvatarUrl == null
                  ? Text(
                      split.displayName.isNotEmpty
                          ? split.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Name
            Expanded(
              child: Text(
                split.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            // Amount & status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${split.amount.toStringAsFixed(2)}฿',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isPaid ? 'จ่ายแล้ว' : 'ค้างจ่าย',
                    style: TextStyle(
                      fontSize: 11,
                      color: isPaid ? Colors.green[700] : Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.delete_outline),
        label: const Text(
          'ลบบิลนี้ชะ!',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    ExpenseDetail detail,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'ลบบิลนี้?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'คุณแน่ใจว่าต้องการลบ "${detail.description}" ?\nการกระทำนี้ไม่สามารถย้อนกลับได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog
              try {
                await ref.read(expenseServiceProvider).deleteExpense(detail.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ลบบิลเรียบร้อยแล้ว')),
                  );
                  context.pop(true); // Return true to refresh parent
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('ลบเลย'),
          ),
        ],
      ),
    );
  }
}
