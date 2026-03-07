import 'package:flutter/material.dart';
import 'package:nubbill/models/settlement_model.dart';
import 'package:nubbill/shared/app_icons.dart';

Future<void> showSettlementHistorySheet(
  BuildContext context, {
  required List<SettlementRecord> settlements,
  String title = 'บันทึกการโอน',
}) async {
  final verified = settlements
      .where((settlement) => settlement.isVerified)
      .toList();
  if (verified.isEmpty) {
    return;
  }

  verified.sort((a, b) {
    final aDate =
        a.verifiedAt ?? DateTime.tryParse(a.createdAt) ?? DateTime.now();
    final bDate =
        b.verifiedAt ?? DateTime.tryParse(b.createdAt) ?? DateTime.now();
    return bDate.compareTo(aDate);
  });

  if (verified.length == 1) {
    return showSettlementDetailModal(context, settlement: verified.first);
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8E0EA),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    AppIcons.receipt,
                    size: 18,
                    color: Color(0xFF4A5A6D),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF141416),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: verified.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final settlement = verified[index];
                    final payerName = settlement.payer?.displayName ?? 'สมาชิก';
                    final payeeName = settlement.payee?.displayName ?? 'สมาชิก';

                    return Material(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await showSettlementDetailModal(
                            context,
                            settlement: settlement,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F6EC),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  AppIcons.checkCircle,
                                  color: Color(0xFF2E7D32),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$payerName -> $payeeName',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Color(0xFF141416),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDateTime(
                                        settlement.verifiedAt ??
                                            DateTime.tryParse(
                                              settlement.createdAt,
                                            ) ??
                                            DateTime.now(),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF7A8797),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${settlement.paidAmount.toStringAsFixed(2)}฿',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                AppIcons.chevronRight,
                                size: 18,
                                color: Color(0xFF9AA8BA),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showSettlementDetailModal(
  BuildContext context, {
  required SettlementRecord settlement,
}) async {
  final payerName = settlement.payer?.displayName ?? 'สมาชิก';
  final payeeName = settlement.payee?.displayName ?? 'สมาชิก';
  final verifiedAt =
      settlement.verifiedAt ??
      DateTime.tryParse(settlement.createdAt) ??
      DateTime.now();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8E0EA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'บันทึกการโอน',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF141416),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFD),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5ECF4)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F6EC),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        AppIcons.checkCircle,
                        color: Color(0xFF2E7D32),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${settlement.paidAmount.toStringAsFixed(2)} บาท',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'โอนสำเร็จแล้ว',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5E6D7F),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _detailRow('ผู้โอน', payerName),
              _detailRow('ผู้รับ', payeeName),
              _detailRow('เวลาโอน', _formatDateTime(verifiedAt)),
              _detailRow('เลขอ้างอิง', settlement.transactionRef ?? '-'),
              _detailRow('สถานะ', 'ยืนยันแล้ว'),
              if (settlement.isPartialPayment)
                _detailRow(
                  'ยอดคงเหลือ',
                  settlement.remainingAmount != null
                      ? '${settlement.remainingAmount!.toStringAsFixed(2)} บาท'
                      : '-',
                ),
              if (settlement.slipImageUrl != null &&
                  settlement.slipImageUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'รูปสลิป',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF141416),
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: Image.network(
                      settlement.slipImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFEFF3F8),
                          child: const Center(
                            child: Text(
                              'ไม่สามารถโหลดรูปสลิปได้',
                              style: TextStyle(color: Color(0xFF7A8797)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81CEF2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'ปิด',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _detailRow(String label, String value) {
  return Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE4EAF1)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A8797),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF141416),
            ),
          ),
        ),
      ],
    ),
  );
}

String _formatDateTime(DateTime dateTime) {
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

  final day = dateTime.day.toString().padLeft(2, '0');
  final month = thaiMonths[dateTime.month];
  final year = dateTime.year + 543;
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$day $month $year • $hour:$minute';
}
