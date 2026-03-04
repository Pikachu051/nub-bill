import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nubbill/shared/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nubbill/services/payment_service.dart';
import 'package:nubbill/services/slip_scanner_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:nubbill/widgets/slip_verification_modal.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final double amount;
  final String? memberId;
  final String? tripId;
  final String? payeeName;
  final String? payeeAvatarUrl;
  final String? promptpayId;
  final List<String>? expenseSplitIds;

  const PaymentScreen({
    super.key,
    this.amount = 0,
    this.memberId,
    this.tripId,
    this.payeeName,
    this.payeeAvatarUrl,
    this.promptpayId,
    this.expenseSplitIds,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _imagePicker = ImagePicker();
  final _slipScannerService = SlipScannerService();

  QrPaymentData? _qrData;
  bool _isLoading = true;
  bool _isPickingSlip = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateQr();
  }

  Future<void> _generateQr() async {
    // If no member/trip info, show manual payment
    if (widget.memberId == null || widget.tripId == null) {
      setState(() {
        _isLoading = false;
        _error = null;
      });
      return;
    }

    try {
      final paymentService = ref.read(paymentServiceProvider);
      final qrData = await paymentService.generateQr(
        payeeMemberId: widget.memberId!,
        tripId: widget.tripId!,
        amount: widget.amount,
        expenseSplitIds: widget.expenseSplitIds ?? [],
      );
      setState(() {
        _qrData = qrData;
        _isLoading = false;
      });
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _error = msg;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สแกนจ่าย'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildPaymentCard(context),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _isPickingSlip ? null : _onAttachSlipPressed,
            icon: _isPickingSlip
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(AppIcons.paperclip),
            label: Text(
              _isPickingSlip ? 'กำลังอ่านสลิป...' : 'แนบสลิปการโอน',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF81CEF2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context) {
    final payeeName = _qrData?.payeeName ?? widget.payeeName ?? 'ผู้รับเงิน';
    final promptpayId = _qrData?.promptpayId ?? widget.promptpayId ?? '-';
    final maskedPromptPayId = _maskPromptpayId(promptpayId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFFEAF7FD),
            backgroundImage: widget.payeeAvatarUrl != null
                ? NetworkImage(widget.payeeAvatarUrl!)
                : null,
            child: widget.payeeAvatarUrl == null
                ? Text(
                    payeeName.isNotEmpty ? payeeName[0] : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      color: Color(0xFF5A5A5A),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            payeeName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F1F1F),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'พร้อมเพย์: $maskedPromptPayId',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6D6D6D),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: promptpayId == '-' ? null : () => _copyPromptpay(promptpayId),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(AppIcons.copy, size: 16, color: Color(0xFF7A7A7A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: 230,
            height: 230,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEDEDED)),
            ),
            child: _error != null
                ? Center(
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFE86868)),
                    ),
                  )
                : (_qrData != null && _qrData!.payload.isNotEmpty)
                ? QrImageView(
                    data: _qrData!.payload,
                    version: QrVersions.auto,
                    backgroundColor: Colors.white,
                  )
                : const Icon(AppIcons.qrCode, size: 120, color: Color(0xFFA8A8A8)),
          ),
          const SizedBox(height: 18),
          const Text(
            'ยอดที่ต้องชำระ',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF777777),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.amount.toStringAsFixed(2)}฿',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Color(0xFF81CEF2),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _saveQrCode,
            icon: const Icon(AppIcons.download, size: 18),
            label: const Text('บันทึกรูป QR Code'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4A4A4A),
              minimumSize: const Size.fromHeight(46),
              side: const BorderSide(color: Color(0xFFE1E1E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onAttachSlipPressed() async {
    if (_isPickingSlip) return;

    setState(() => _isPickingSlip = true);
    var verifyingModalVisible = false;
    try {
      final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (!mounted || pickedFile == null) {
        return;
      }

      _showModal(SlipVerificationModalState.verifying, dismissible: false);
      verifyingModalVisible = true;

      final parsedData = await _slipScannerService.scanSlipImage(pickedFile.path);

      if (mounted && verifyingModalVisible) {
        Navigator.of(context, rootNavigator: true).pop();
        verifyingModalVisible = false;
      }

      if (!mounted) return;

      if (parsedData == null ||
          (parsedData.transactionRef == null || parsedData.transactionRef!.isEmpty) ||
          _qrData?.settlementId == null) {
        await _showModal(
          SlipVerificationModalState.unreadable,
          onAttachSlip: _retryAttachSlip,
        );
        return;
      }

      final paymentService = ref.read(paymentServiceProvider);
      final result = await paymentService.verifySlipData(
        settlementId: _qrData!.settlementId!,
        amount: parsedData.amount ?? 0,
        receiverId: parsedData.receiverId ?? '',
        transactionRef: parsedData.transactionRef!,
      );

      if (!mounted) return;

      if (result.success && result.status == 'success') {
        _showModal(SlipVerificationModalState.success, dismissible: false);
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          Navigator.of(context).maybePop(true);
        }
        return;
      }

      if (result.status == 'partial_payment' || result.status == 'amount_mismatch') {
        await _showModal(
          SlipVerificationModalState.amountMismatch,
          onAttachSlip: _retryAttachSlip,
          paidAmount: result.paidAmount,
          deductedAmount: result.paidAmount,
          remainingAmount: result.remainingAmount,
        );
        return;
      }

      if (result.status == 'duplicate' || result.isDuplicate) {
        await _showModal(
          SlipVerificationModalState.duplicate,
          onAttachSlip: _retryAttachSlip,
        );
        return;
      }

      await _showModal(
        SlipVerificationModalState.unreadable,
        onAttachSlip: _retryAttachSlip,
      );
    } catch (_) {
      if (mounted && verifyingModalVisible) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        await _showModal(
          SlipVerificationModalState.unreadable,
          onAttachSlip: _retryAttachSlip,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingSlip = false);
      }
    }
  }

  Future<void> _showModal(
    SlipVerificationModalState state, {
    bool dismissible = true,
    VoidCallback? onAttachSlip,
    double? paidAmount,
    double? deductedAmount,
    double? remainingAmount,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (context) => SlipVerificationModal(
        state: state,
        onAttachSlip: onAttachSlip,
        paidAmount: paidAmount,
        deductedAmount: deductedAmount,
        remainingAmount: remainingAmount,
      ),
    );
  }

  void _retryAttachSlip() {
    Navigator.of(context, rootNavigator: true).pop();
    _onAttachSlipPressed();
  }

  void _copyPromptpay(String id) {
    Clipboard.setData(ClipboardData(text: id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คัดลอกพร้อมเพย์แล้ว')),
    );
  }

  void _saveQrCode() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('บันทึกรูป QR Code แล้ว')));
  }

  String _maskPromptpayId(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) {
      return value;
    }
    return '${digits.substring(0, 3)}-xxx-xxxx';
  }
}
