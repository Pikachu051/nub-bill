import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';
import 'package:go_router/go_router.dart';

class FriendBillItem {
  final String splitId;
  final String expenseId;
  final String title;
  final DateTime date;
  final double amount;
  final IconData icon;
  final Color iconBackground;

  const FriendBillItem({
    required this.splitId,
    required this.expenseId,
    required this.title,
    required this.date,
    required this.amount,
    required this.icon,
    required this.iconBackground,
  });
}

class FriendBillsPage extends StatefulWidget {
  final String groupId;
  final String friendName;
  final String friendMemberId;
  final String? friendAvatarUrl;
  final List<FriendBillItem> bills;
  final List<String> counterSplitIds;

  const FriendBillsPage({
    super.key,
    required this.groupId,
    required this.friendName,
    required this.friendMemberId,
    this.friendAvatarUrl,
    required this.bills,
    this.counterSplitIds = const [],
  });

  @override
  State<FriendBillsPage> createState() => _FriendBillsPageState();
}

class _FriendBillsPageState extends State<FriendBillsPage> {
  late Set<String> _selectedSplitIds;

  @override
  void initState() {
    super.initState();
    _selectedSplitIds = widget.bills.map((bill) => bill.splitId).toSet();
  }

  bool get _allSelected =>
      widget.bills.isNotEmpty &&
      _selectedSplitIds.length == widget.bills.length;

  int get _selectedCount => _selectedSplitIds.length;

  double get _selectedTotal {
    double total = 0;
    for (final bill in widget.bills) {
      if (_selectedSplitIds.contains(bill.splitId)) {
        total += bill.amount;
      }
    }
    return total;
  }

  void _toggleSplit(String splitId) {
    setState(() {
      if (_selectedSplitIds.contains(splitId)) {
        _selectedSplitIds.remove(splitId);
      } else {
        _selectedSplitIds.add(splitId);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedSplitIds.clear();
      } else {
        _selectedSplitIds = widget.bills.map((bill) => bill.splitId).toSet();
      }
    });
  }

  Future<void> _scanToPay() async {
    if (_selectedSplitIds.isEmpty) {
      return;
    }

    final result = await context.push<bool?>(
      '/payment',
      extra: {
        'amount': _selectedTotal,
        'memberId': widget.friendMemberId,
        'tripId': widget.groupId,
        'payeeName': widget.friendName,
        'payeeAvatarUrl': widget.friendAvatarUrl,
        'expenseSplitIds': _selectedSplitIds.toList(),
        if (_allSelected && widget.counterSplitIds.isNotEmpty)
          'counterExpenseSplitIds': widget.counterSplitIds,
      },
    );

    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F4F4),
        surfaceTintColor: const Color(0xFFF4F4F4),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'รายการของ ${widget.friendName}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF525252),
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            AppIcons.chevronLeft,
            color: Color(0xFF5E5E5E),
            size: 26,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _toggleSelectAll,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF82CEF2),
              padding: const EdgeInsets.only(right: 14),
              splashFactory: NoSplash.splashFactory,
              overlayColor: Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(
                  _allSelected
                      ? AppIcons.checkCircleFilled
                      : AppIcons.circleUnchecked,
                  size: 16,
                ),
                const SizedBox(width: 4),
                const Text(
                  'เลือกทั้งหมด',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.bills.isEmpty
                ? const Center(
                    child: Text(
                      'ยังไม่มีรายการค้างจ่าย',
                      style: TextStyle(color: Color(0xFF909090), fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                    itemCount: widget.bills.length,
                    itemBuilder: (context, index) {
                      final bill = widget.bills[index];
                      final selected = _selectedSplitIds.contains(bill.splitId);

                      return _BillRow(
                        key: ValueKey(bill.splitId),
                        bill: bill,
                        selected: selected,
                        onTap: () => _toggleSplit(bill.splitId),
                      );
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(22, 10, 22, 16 + bottomInset),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F4),
              border: Border(
                top: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RichText(
                  textAlign: TextAlign.right,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6F6F6F),
                      fontWeight: FontWeight.w400,
                      fontFamily: 'LINESeedSansTH',
                    ),
                    children: [
                      const TextSpan(text: 'รวม: '),
                      TextSpan(
                        text: '$_selectedCount รายการ',
                        style: const TextStyle(
                          color: Color(0xFF7CC8ED),
                          fontWeight: FontWeight.w600,
                          fontFamily: 'LINESeedSansTH',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _selectedSplitIds.isEmpty ? null : _scanToPay,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF81CEF2),
                      disabledBackgroundColor: const Color(0xFFC7E8F8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    icon: const Icon(AppIcons.qrCode, color: Colors.white),
                    label: Text(
                      'สแกนจ่าย ${_selectedTotal.toStringAsFixed(2)}฿',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'LINESeedSansTH',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final FriendBillItem bill;
  final bool selected;
  final VoidCallback onTap;

  const _BillRow({
    super.key,
    required this.bill,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 9, 20, 9),
        child: Row(
          children: [
            Icon(
              selected ? AppIcons.checkCircleFilled : AppIcons.circleUnchecked,
              color: selected
                  ? const Color(0xFF80CDF1)
                  : const Color(0xFFC6CDD2),
              size: 20,
            ),
            const SizedBox(width: 12),
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: bill.iconBackground,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(bill.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF696969),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatThaiShortDate(bill.date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8C8C8C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'คุณค้างจ่าย',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFF7C7C),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  '${bill.amount.toStringAsFixed(2)}฿',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFFF6F6F),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatThaiShortDate(DateTime date) {
    final buddhistYear2Digits = (date.year + 543) % 100;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = buddhistYear2Digits.toString().padLeft(2, '0');
    return '$day/$month/$year';
  }
}
