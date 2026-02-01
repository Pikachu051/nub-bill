import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/config/api_config.dart';

/// Provider for PaymentService
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(ApiClient());
});

/// QR generation response
class QrPaymentData {
  final String type;
  final String payload;
  final String promptpayId;
  final double amount;
  final String? payeeName;
  final String? settlementId;

  QrPaymentData({
    required this.type,
    required this.payload,
    required this.promptpayId,
    required this.amount,
    this.payeeName,
    this.settlementId,
  });

  factory QrPaymentData.fromJson(Map<String, dynamic> json) {
    return QrPaymentData(
      type: json['type'] as String? ?? 'promptpay',
      payload: json['payload'] as String? ?? '',
      promptpayId: json['promptpay_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      payeeName: json['payee_name'] as String?,
      settlementId: json['settlement_id'] as String?,
    );
  }
}

/// Slip verification result
class SlipVerificationResult {
  final bool success;
  final String? message;
  final bool? isOverpaid;
  final Map<String, dynamic>? slipData;

  SlipVerificationResult({
    required this.success,
    this.message,
    this.isOverpaid,
    this.slipData,
  });

  factory SlipVerificationResult.fromJson(Map<String, dynamic> json) {
    return SlipVerificationResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      isOverpaid: json['is_overpaid'] as bool?,
      slipData: json['slip_data'] as Map<String, dynamic>?,
    );
  }
}

/// Service for Payment API calls
class PaymentService {
  final ApiClient _client;

  PaymentService(this._client);

  /// POST /api/payment/generate-qr - Generate PromptPay QR payload
  Future<QrPaymentData> generateQr({
    required String payeeMemberId,
    required String tripId,
    required double amount,
    required List<String> expenseSplitIds,
  }) async {
    final response = await _client.post(
      '/payment/generate-qr',
      body: {
        'payee_member_id': payeeMemberId,
        'trip_id': tripId,
        'amount': amount,
        'expense_split_ids': expenseSplitIds,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to generate QR code');
    }

    return QrPaymentData.fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /api/payment/verify-slip - Upload and verify payment slip
  Future<SlipVerificationResult> verifySlip({
    required String settlementId,
    required List<int> slipBytes,
    required String fileName,
  }) async {
    // Create multipart request for file upload
    final response = await _client.post(
      '/payment/verify-slip',
      body: {
        'settlement_id': settlementId,
        // Note: Actual file upload would need multipart handling
        // For now, we'll base64 encode the image
        'slip_image': slipBytes,
        'file_name': fileName,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to verify slip');
    }

    return SlipVerificationResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// GET /api/payment/settlements/:id - Get settlement status
  Future<Map<String, dynamic>> getSettlementStatus(String settlementId) async {
    final response = await _client.get('/payment/settlements/$settlementId');

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to get settlement status');
    }

    return response.data as Map<String, dynamic>;
  }
}
