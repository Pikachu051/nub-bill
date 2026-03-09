import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:nubbill/shared/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nubbill/services/payment_service.dart';
import 'package:nubbill/services/slip_scanner_service.dart';
import 'package:path_provider/path_provider.dart';
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
  final List<String>? counterExpenseSplitIds;

  const PaymentScreen({
    super.key,
    this.amount = 0,
    this.memberId,
    this.tripId,
    this.payeeName,
    this.payeeAvatarUrl,
    this.promptpayId,
    this.expenseSplitIds,
    this.counterExpenseSplitIds,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _imagePicker = ImagePicker();
  final _slipScannerService = SlipScannerService();
  final _qrKey = GlobalKey();

  QrPaymentData? _qrData;
  bool _isLoading = true;
  bool _isPickingSlip = false;
  String? _error;
  SlipVerificationController? _verificationController;

  @override
  void initState() {
    super.initState();
    _generateQr();
  }

  @override
  void dispose() {
    _verificationController?.dispose();
    super.dispose();
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
        counterExpenseSplitIds: widget.counterExpenseSplitIds ?? [],
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
            child: RepaintBoundary(
              key: _qrKey,
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

    // Create controller starting at verifying state.
    _verificationController?.dispose();
    _verificationController = SlipVerificationController(
      const SlipVerificationDisplayState(
        modalState: SlipVerificationModalState.verifying,
      ),
    );

    // Open a single persistent dialog driven by the controller.
    // The dialog stays open through local scan AND backend verification,
    // then animates to the result state in-place.
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (ctx) =>
          SlipVerificationModal(controller: _verificationController!),
    ));

    try {
      final pickedFile =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (!mounted || pickedFile == null) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        return;
      }

      // Both scan and backend call happen while modal shows verifying state.
      final parsedData =
          await _slipScannerService.scanSlipImage(pickedFile.path);

      if (!mounted) return;

      if (parsedData == null || _qrData?.settlementId == null) {
        _verificationController?.update(SlipVerificationDisplayState(
          modalState: SlipVerificationModalState.unreadable,
          onAttachSlip: _retryAttachSlip,
        ));
        return;
      }

      final paymentService = ref.read(paymentServiceProvider);
      final result = await paymentService.verifySlipData(
        settlementId: _qrData!.settlementId!,
        amount: parsedData.amount ?? 0,
        receiverId: parsedData.receiverId ?? '',
        transactionRef: parsedData.transactionRef,
        rawPayload: parsedData.rawPayload,
        settlementToken: _qrData?.settlementToken,
      );

      if (!mounted) return;

      if (result.success && result.status == 'success') {
        _verificationController?.update(const SlipVerificationDisplayState(
          modalState: SlipVerificationModalState.success,
        ));
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          Navigator.of(context).maybePop(true);
        }
        return;
      }

      if (result.status == 'partial_payment' ||
          result.status == 'amount_mismatch') {
        _verificationController?.update(SlipVerificationDisplayState(
          modalState: SlipVerificationModalState.amountMismatch,
          onAttachSlip: _retryAttachSlip,
          paidAmount: result.paidAmount,
          deductedAmount: result.paidAmount,
          remainingAmount: result.remainingAmount,
        ));
        return;
      }

      if (result.status == 'duplicate' || result.isDuplicate) {
        _verificationController?.update(SlipVerificationDisplayState(
          modalState: SlipVerificationModalState.duplicate,
          onAttachSlip: _retryAttachSlip,
        ));
        return;
      }

      if (result.status == 'receiver_mismatch') {
        if (mounted && result.message != null && result.message!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message!),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _verificationController?.update(SlipVerificationDisplayState(
          modalState: SlipVerificationModalState.unreadable,
          onAttachSlip: _retryAttachSlip,
        ));
        return;
      }

      if (result.status == 'needs_review') {
        _verificationController?.update(SlipVerificationDisplayState(
          modalState: SlipVerificationModalState.needsReview,
          onClose: _closeVerificationDialog,
        ));
        return;
      }

      _verificationController?.update(SlipVerificationDisplayState(
        modalState: SlipVerificationModalState.unreadable,
        onAttachSlip: _retryAttachSlip,
      ));
    } catch (_) {
      if (mounted) {
        _verificationController?.update(SlipVerificationDisplayState(
          modalState: SlipVerificationModalState.unreadable,
          onAttachSlip: _retryAttachSlip,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingSlip = false);
      }
    }
  }

  void _retryAttachSlip() {
    Navigator.of(context, rootNavigator: true).pop();
    // _onAttachSlipPressed has already completed (finally ran, _isPickingSlip=false)
    // so re-entry guard is clear and we can call directly.
    _onAttachSlipPressed();
  }

  void _closeVerificationDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _copyPromptpay(String id) {
    Clipboard.setData(ClipboardData(text: id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คัดลอกพร้อมเพย์แล้ว')),
    );
  }

  Future<void> _saveQrCode() async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/nubbill_promptpay_qr.png');
      await file.writeAsBytes(pngBytes);

      await Gal.putImage(file.path, album: 'NubBill');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึก QR Code ลงในคลังภาพแล้ว')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถบันทึก QR Code: $e')),
        );
      }
    }
  }

  String _maskPromptpayId(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) {
      return value;
    }
    return '${digits.substring(0, 3)}-xxx-xxxx';
  }
}
