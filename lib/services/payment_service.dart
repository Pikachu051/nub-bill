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

  /// Create settlement for manual verification flow.
  ///
  /// Uses the same endpoint as QR generation and returns the created settlement ID.
  Future<String> createSettlementForManualVerify({
    required String payerMemberId,
    required String payeeMemberId,
    required String tripId,
    required double amount,
    required List<String> expenseSplitIds,
  }) async {
    final createSettlementResponse = await _client.post(
      '/payment/create-settlement',
      body: {
        'payer_member_id': payerMemberId,
        'payee_member_id': payeeMemberId,
        'trip_id': tripId,
        'amount': amount,
        'expense_split_ids': expenseSplitIds,
      },
    );

    if (createSettlementResponse.isSuccess &&
        createSettlementResponse.data != null) {
      final data = createSettlementResponse.data as Map<String, dynamic>;
      final settlementId = data['settlement_id'] as String?;
      if (settlementId != null && settlementId.isNotEmpty) {
        return settlementId;
      }
    }

    // Backward compatibility fallback when backend does not support /create-settlement.
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
      throw Exception(response.error ?? 'Failed to create settlement');
    }

    final data = response.data as Map<String, dynamic>;
    final settlementId = data['settlement_id'] as String?;
    if (settlementId == null || settlementId.isEmpty) {
      throw Exception('ไม่สามารถสร้างรายการยืนยันรับเงินได้');
    }

    return settlementId;
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

  /// POST /api/payment/manual-verify - Verify payment manually (without slip)
  Future<Map<String, dynamic>> manualVerify({
    required String settlementId,
  }) async {
    final response = await _client.post(
      '/payment/manual-verify',
      body: {'settlement_id': settlementId},
    );

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to manually verify payment');
    }

    return response.data as Map<String, dynamic>;
  }
}
