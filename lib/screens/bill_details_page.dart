import 'package:flutter/material.dart';
import 'package:nubbill/models/bill_participant.dart';

class BillDetailsPage extends StatefulWidget {
  final String billId;
  final String billTitle;
  final double totalAmount;
  final IconData categoryIcon;
  final DateTime date;

  const BillDetailsPage({
    super.key,
    required this.billId,
    required this.billTitle,
    required this.totalAmount,
    required this.categoryIcon,
    required this.date,
  });

  @override
  State<BillDetailsPage> createState() => _BillDetailsPageState();
}

class _BillDetailsPageState extends State<BillDetailsPage> {
  static const Color primaryColor = Color.fromARGB(255, 129, 206, 242);
  static const Color secondaryColor = Color(0xFFFFC4A3);
  static const Color pinkAccent = Color(0xFFFFB5B5);

  // Mock data - payer
  final String _payerName = 'ออร่า';

  // Mock data - participants
  final List<BillParticipant> _participants = [
    BillParticipant(id: '1', name: 'ออร่า', amount: 225.00, isPaid: true),
    BillParticipant(
      id: '2',
      name: 'หมอนชาเขียว',
      amount: 225.00,
      isPaid: false,
    ),
  ];

  void _onDeleteBill() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบบิลนี้?'),
        content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบบิลนี้?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to group detail
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ลบบิลเรียบร้อยแล้ว')),
              );
            },
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
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
    return '${date.day} ${months[date.month - 1]} ${date.year % 100} 12:47 น.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'รายละเอียดบิล',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: primaryColor),
            onPressed: () {
              // TODO: Navigate to edit bill page
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    // Bill card
                    _buildBillCard(),

                    const SizedBox(height: 24),

                    // Divider
                    Container(height: 1, color: Colors.grey[300]),

                    const SizedBox(height: 24),

                    // Participants section
                    _buildParticipantsSection(),
                  ],
                ),
              ),
            ),
          ),

          // Delete button
          _buildDeleteButton(),
        ],
      ),
    );
  }

  Widget _buildBillCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Category icon with gradient background
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withValues(alpha: 0.4),
                  secondaryColor.withValues(alpha: 0.4),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(widget.categoryIcon, color: primaryColor, size: 36),
          ),

          const SizedBox(height: 16),

          // Bill title
          Text(
            widget.billTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          // Date
          Text(
            _formatDate(widget.date),
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),

          const SizedBox(height: 24),

          // Total amount with checkmark
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green[400], size: 28),
              const SizedBox(width: 8),
              Text(
                '${widget.totalAmount.toStringAsFixed(2)}฿',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: primaryColor,
                  size: 18,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Paid by
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'จ่ายโดย: ',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              CircleAvatar(
                radius: 14,
                backgroundColor: pinkAccent.withValues(alpha: 0.3),
                child: Text(
                  _payerName[0],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: pinkAccent,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _payerName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ใครหารบ้าง? (${_participants.length} คน)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ...List.generate(
            _participants.length,
            (index) => _buildParticipantItem(index + 1, _participants[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantItem(int index, BillParticipant participant) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // Index number
          SizedBox(
            width: 24,
            child: Text(
              '$index.',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: participant.isPaid
                ? Colors.green.withValues(alpha: 0.2)
                : pinkAccent.withValues(alpha: 0.2),
            child: Text(
              participant.name[0],
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: participant.isPaid ? Colors.green : pinkAccent,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name
          Expanded(
            child: Text(participant.name, style: const TextStyle(fontSize: 16)),
          ),

          // Amount with optional checkmark
          Row(
            children: [
              Text(
                '${participant.amount.toStringAsFixed(2)}฿',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (participant.isPaid) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle, color: Colors.green[400], size: 20),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _onDeleteBill,
            style: ElevatedButton.styleFrom(
              backgroundColor: pinkAccent.withValues(alpha: 0.15),
              foregroundColor: pinkAccent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline, size: 22),
                SizedBox(width: 8),
                Text(
                  'ลบบิลนี้ซะ!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
