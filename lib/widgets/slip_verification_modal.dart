import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';

enum SlipVerificationModalState {
  verifying,
  success,
  unreadable,
  amountMismatch,
  duplicate,
}

class SlipVerificationModal extends StatelessWidget {
  final SlipVerificationModalState state;
  final VoidCallback? onAttachSlip;
  final double? paidAmount;
  final double? deductedAmount;
  final double? remainingAmount;

  const SlipVerificationModal({
    super.key,
    required this.state,
    this.onAttachSlip,
    this.paidAmount,
    this.deductedAmount,
    this.remainingAmount,
  });

  bool get _showAction =>
      state == SlipVerificationModalState.unreadable ||
      state == SlipVerificationModalState.amountMismatch ||
      state == SlipVerificationModalState.duplicate;

  @override
  Widget build(BuildContext context) {
    final content = _contentForState();

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            content.icon,
            const SizedBox(height: 16),
            Text(
              content.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D1D1F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Color(0xFF7D7D7D),
              ),
            ),
            if (state == SlipVerificationModalState.amountMismatch &&
                paidAmount != null &&
                remainingAmount != null) ...[
              const SizedBox(height: 14),
              _InfoLine(label: 'ยอดที่โอนมา', value: '${paidAmount!.toStringAsFixed(2)}฿'),
              _InfoLine(
                label: 'ยอดที่หักหนี้แล้ว',
                value: '${(deductedAmount ?? paidAmount!).toStringAsFixed(2)}฿',
              ),
              _InfoLine(
                label: 'ยอดคงเหลือ',
                value: '${remainingAmount!.toStringAsFixed(2)}฿',
                valueColor: const Color(0xFFE35D5D),
              ),
            ],
            if (_showAction) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAttachSlip,
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF81CEF2),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(AppIcons.paperclip, size: 18),
                  label: const Text(
                    'แนบสลิป',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _ModalContent _contentForState() {
    switch (state) {
      case SlipVerificationModalState.verifying:
        return _ModalContent(
          icon: const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 5,
              color: Color(0xFFF6C66A),
            ),
          ),
          title: 'กำลังส่องสลิปให้!',
          subtitle: 'รอนับบิลแป๊บนึงน้า... ระบบกำลังเช็คยอดเงินให้อยู่',
        );
      case SlipVerificationModalState.success:
        return _ModalContent(
          icon: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFF39C188),
              shape: BoxShape.circle,
            ),
            child: const Icon(AppIcons.badgeCheck, color: Colors.white, size: 30),
          ),
          title: 'ยอดครบถ้วนจ้า!',
          subtitle: 'อัปเดตสถานะกระเป๋าตังค์ พร้อมแจ้งเตือนเพื่อนให้แล้วน้า',
        );
      case SlipVerificationModalState.unreadable:
        return _ModalContent(
          icon: _errorIcon(),
          title: 'เอ๊ะ! อ่านสลิปไม่ได้',
          subtitle: 'หับหา QR Code ไม่เจอเลย แนบสลิปใหม่ที่ชัดกว่านี้อีกทีน้า',
        );
      case SlipVerificationModalState.amountMismatch:
        return _ModalContent(
          icon: _errorIcon(),
          title: 'อุ้ย! ยอดเงินไม่ตรง',
          subtitle: 'ยอดในสลิปไม่เท่ากับยอดที่ค้าง ลองเช็คแล้วแนบสลิปใหม่หน่อยน้า',
        );
      case SlipVerificationModalState.duplicate:
        return _ModalContent(
          icon: _errorIcon(),
          title: 'หืม? สลิปนี้ใช้ไปแล้วนะ',
          subtitle: 'เหมือนสลิปนี้เคยส่งไปแล้วเลย ลองเช็คแล้วแนบสลิปใหม่หน่อยน้า',
        );
    }
  }

  Widget _errorIcon() {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xFFE86868),
        shape: BoxShape.circle,
      ),
      child: const Icon(AppIcons.errorOutline, color: Colors.white, size: 30),
    );
  }
}

class _ModalContent {
  final Widget icon;
  final String title;
  final String subtitle;

  const _ModalContent({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6F6F6F),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? const Color(0xFF1F1F1F),
            ),
          ),
        ],
      ),
    );
  }
}
