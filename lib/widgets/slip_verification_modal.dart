import 'package:flutter/material.dart';
import 'package:nubbill/shared/app_icons.dart';

enum SlipVerificationModalState {
  verifying,
  success,
  unreadable,
  amountMismatch,
  duplicate,
  needsReview,
}

/// Holds all data needed to render one modal state.
class SlipVerificationDisplayState {
  final SlipVerificationModalState modalState;
  final VoidCallback? onAttachSlip;
  final VoidCallback? onClose;
  final double? paidAmount;
  final double? deductedAmount;
  final double? remainingAmount;

  const SlipVerificationDisplayState({
    required this.modalState,
    this.onAttachSlip,
    this.onClose,
    this.paidAmount,
    this.deductedAmount,
    this.remainingAmount,
  });

  bool get isDismissible =>
      modalState != SlipVerificationModalState.verifying &&
      modalState != SlipVerificationModalState.success;

  bool get showAttachSlipAction =>
      modalState == SlipVerificationModalState.unreadable ||
      modalState == SlipVerificationModalState.amountMismatch ||
      modalState == SlipVerificationModalState.duplicate;
}

/// Controls the slip verification modal state from outside the dialog.
class SlipVerificationController extends ChangeNotifier {
  SlipVerificationDisplayState _state;

  SlipVerificationController(this._state);

  SlipVerificationDisplayState get state => _state;

  void update(SlipVerificationDisplayState newState) {
    _state = newState;
    notifyListeners();
  }
}

/// A persistent modal dialog whose content animates between verification states.
///
/// Open once with [showDialog] and drive state changes via [SlipVerificationController].
class SlipVerificationModal extends StatefulWidget {
  final SlipVerificationController controller;

  const SlipVerificationModal({
    super.key,
    required this.controller,
  });

  @override
  State<SlipVerificationModal> createState() => _SlipVerificationModalState();
}

class _SlipVerificationModalState extends State<SlipVerificationModal> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final display = widget.controller.state;

    return PopScope(
      canPop: display.isDismissible,
      child: Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeIn,
                  ),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              child: _ModalContent(
                key: ValueKey(display.modalState),
                display: display,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModalContent extends StatelessWidget {
  final SlipVerificationDisplayState display;

  const _ModalContent({
    super.key,
    required this.display,
  });

  @override
  Widget build(BuildContext context) {
    final state = display.modalState;
    final content = _contentDataForState(state);

    return Column(
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
            display.paidAmount != null &&
            display.remainingAmount != null) ...[
          const SizedBox(height: 14),
          _InfoLine(
            label: 'ยอดที่โอนมา',
            value: '${display.paidAmount!.toStringAsFixed(2)}฿',
          ),
          _InfoLine(
            label: 'ยอดที่หักหนี้แล้ว',
            value:
                '${(display.deductedAmount ?? display.paidAmount!).toStringAsFixed(2)}฿',
          ),
          _InfoLine(
            label: 'ยอดคงเหลือ',
            value: '${display.remainingAmount!.toStringAsFixed(2)}฿',
            valueColor: const Color(0xFFE35D5D),
          ),
        ],
        if (display.showAttachSlipAction) ...[
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: display.onAttachSlip,
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
        if (state == SlipVerificationModalState.needsReview) ...[
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: display.onClose,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD9D9D9)),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'ปิด',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF888888),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  _ModalContentData _contentDataForState(SlipVerificationModalState state) {
    switch (state) {
      case SlipVerificationModalState.verifying:
        return _ModalContentData(
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
        return _ModalContentData(
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
        return _ModalContentData(
          icon: _errorIcon(),
          title: 'เอ๊ะ! อ่านสลิปไม่ได้',
          subtitle: 'หับหา QR Code ไม่เจอเลย แนบสลิปใหม่ที่ชัดกว่านี้อีกทีน้า',
        );
      case SlipVerificationModalState.amountMismatch:
        return _ModalContentData(
          icon: _errorIcon(),
          title: 'อุ้ย! ยอดเงินไม่ตรง',
          subtitle: 'ยอดในสลิปไม่เท่ากับยอดที่ค้าง ลองเช็คแล้วแนบสลิปใหม่หน่อยน้า',
        );
      case SlipVerificationModalState.duplicate:
        return _ModalContentData(
          icon: _errorIcon(),
          title: 'หืม? สลิปนี้ใช้ไปแล้วนะ',
          subtitle: 'เหมือนสลิปนี้เคยส่งไปแล้วเลย ลองเช็คแล้วแนบสลิปใหม่หน่อยน้า',
        );
      case SlipVerificationModalState.needsReview:
        return _ModalContentData(
          icon: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFF6C66A),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              AppIcons.notificationsActive,
              color: Colors.white,
              size: 30,
            ),
          ),
          title: 'รอยืนยันจากผู้รับเงิน',
          subtitle: 'ระบบรับสลิปไว้แล้ว รอให้ผู้รับเงินกดยืนยันรับเงินอีกทีน้า',
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

class _ModalContentData {
  final Widget icon;
  final String title;
  final String subtitle;

  const _ModalContentData({
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



