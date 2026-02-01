import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/widgets/rounded_button.dart';
import 'package:nubbill/services/payment_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final double amount;
  final String? memberId;
  final String? tripId;
  final List<String>? expenseSplitIds;

  const PaymentScreen({
    super.key,
    this.amount = 0,
    this.memberId,
    this.tripId,
    this.expenseSplitIds,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  QrPaymentData? _qrData;
  bool _isLoading = true;
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
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สแกนจ่าย'),
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
                    const Text(
                      'แสกน QR Code เพื่อจ่ายเงิน',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ยอดที่ต้องชำระ: ฿${widget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),

                    // QR Code Container
                    Container(
                      width: 280,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_error != null)
                            Column(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'ไม่สามารถสร้าง QR ได้',
                                  style: TextStyle(color: Colors.red[700]),
                                ),
                              ],
                            )
                          else if (_qrData != null &&
                              _qrData!.payload.isNotEmpty)
                            QrImageView(
                              data: _qrData!.payload,
                              version: QrVersions.auto,
                              size: 200.0,
                              backgroundColor: Colors.white,
                            )
                          else
                            const Column(
                              children: [
                                Icon(
                                  Icons.qr_code_2,
                                  size: 150,
                                  color: Colors.black,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'PromptPay',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    Card(
                      elevation: 0,
                      color: Colors.grey[50],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('โอนไปที่:'),
                                Text(
                                  _qrData?.payeeName ?? 'ผู้รับเงิน',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('เบอร์พร้อมเพย์:'),
                                Text(
                                  _qrData?.promptpayId ?? '-',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('จำนวน:'),
                                Text(
                                  '฿${widget.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF81CEF2),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    RoundedButton(
                      text: 'แนบสลิปโอนเงิน',
                      backgroundColor: const Color(0xFF81CEF2),
                      textColor: Colors.white,
                      onPressed: () {
                        context.push(
                          '/upload_slip',
                          extra: {
                            'settlementId': _qrData?.settlementId,
                            'amount': widget.amount,
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('บันทึก QR Code แล้ว')),
                        );
                      },
                      child: const Text(
                        'บันทึก QR Code',
                        style: TextStyle(color: Color(0xFF81CEF2)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
