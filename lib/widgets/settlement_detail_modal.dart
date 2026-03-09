import 'package:flutter/material.dart';
import 'package:nubbill/models/settlement_model.dart';
import 'package:nubbill/shared/app_icons.dart';

const String _kFont = 'LINESeedSansTH';

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
                  color: Color(0xB2141416),
                  fontSize: 20,
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0x19141416)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1E333333),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3DCB57),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            AppIcons.check,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'เคลียร์ยอดเรียบร้อย',
                              style: TextStyle(
                                color: Color(0xB2141416),
                                fontSize: 16,
                                fontFamily: _kFont,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatDateTimeCompact(verifiedAt),
                              style: const TextStyle(
                                color: Color(0x4C141416),
                                fontSize: 12,
                                fontFamily: _kFont,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${settlement.paidAmount.toStringAsFixed(2)}฿',
                          style: const TextStyle(
                            color: Color(0xB2141416),
                            fontSize: 24,
                            fontFamily: _kFont,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF81CEF2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            AppIcons.receipt,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'โอนสำเร็จแล้ว',
                      style: TextStyle(
                        color: Color(0x7F141416),
                        fontSize: 12,
                        fontFamily: _kFont,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _payerReceiverRow(
                      payerName: payerName,
                      payerAvatarUrl: settlement.payer?.avatarUrl,
                      payeeName: payeeName,
                      payeeAvatarUrl: settlement.payee?.avatarUrl,
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

Widget _payerReceiverRow({
  required String payerName,
  required String? payerAvatarUrl,
  required String payeeName,
  required String? payeeAvatarUrl,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _memberChip(name: payerName, avatarUrl: payerAvatarUrl),
      const SizedBox(width: 8),
      const Icon(AppIcons.chevronRight, size: 16, color: Color(0x7F141416)),
      const SizedBox(width: 8),
      _memberChip(name: payeeName, avatarUrl: payeeAvatarUrl),
    ],
  );
}

Widget _memberChip({required String name, required String? avatarUrl}) {
  final displayName = name.trim().isEmpty ? 'สมาชิก' : name.trim();

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0x1981CEF2),
        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
            ? NetworkImage(avatarUrl)
            : null,
        child: avatarUrl == null || avatarUrl.isEmpty
            ? Text(
                displayName[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF81CEF2),
                  fontSize: 14,
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
      const SizedBox(width: 8),
      Text(
        displayName,
        style: const TextStyle(
          color: Color(0xB2141416),
          fontSize: 14,
          fontFamily: _kFont,
          fontWeight: FontWeight.w400,
        ),
      ),
    ],
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
              fontWeight: FontWeight.w400,
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

String _formatDateTimeCompact(DateTime dateTime) {
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

  final day = dateTime.day.toString();
  final month = thaiMonths[dateTime.month];
  final shortYear = ((dateTime.year + 543) % 100).toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$day $month $shortYear $hour:$minute น.';
}
