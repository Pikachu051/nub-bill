import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/config/api_config.dart';
import 'package:nubbill/models/settlement_model.dart';
import 'package:nubbill/services/auth_repository.dart';

/// Provider for PaymentService
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(ApiClient());
});

final tripSettlementsProvider = FutureProvider.autoDispose
    .family<List<SettlementRecord>, String>((ref, tripId) async {
      final userId = ref.watch(authUserIdProvider);
      if (userId == null) return [];

      final service = ref.read(paymentServiceProvider);
      return service.getTripSettlements(tripId);
    });

final settlementDetailProvider = FutureProvider.autoDispose
    .family<SettlementRecord?, String>((ref, settlementId) async {
      final userId = ref.watch(authUserIdProvider);
      if (userId == null) return null;

      final service = ref.read(paymentServiceProvider);
      return service.getSettlementStatus(settlementId);
    });

/// QR generation response
class QrPaymentData {
  final String type;
  final String payload;
  final String promptpayId;
  final double amount;
  final String? payeeName;
  final String? settlementId;
  final String? settlementToken;

  QrPaymentData({
    required this.type,
    required this.payload,
    required this.promptpayId,
    required this.amount,
    this.payeeName,
    this.settlementId,
    this.settlementToken,
  });

  factory QrPaymentData.fromJson(Map<String, dynamic> json) {
    return QrPaymentData(
      type: json['type'] as String? ?? 'promptpay',
      payload: json['payload'] as String? ?? '',
      promptpayId: json['promptpay_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      payeeName: json['payee_name'] as String?,
      settlementId: json['settlement_id'] as String?,
      settlementToken: json['settlement_token'] as String?,
    );
  }
}

/// Slip verification result
class SlipVerificationResult {
  final bool success;
  final String status;
  final String? message;
  final double? paidAmount;
  final double? remainingAmount;
  final bool isDuplicate;

  SlipVerificationResult({
    required this.success,
    required this.status,
    this.message,
    this.paidAmount,
    this.remainingAmount,
    this.isDuplicate = false,
  });

  factory SlipVerificationResult.fromJson(Map<String, dynamic> json) {
    return SlipVerificationResult(
      success: json['success'] as bool? ?? false,
      status: json['status'] as String? ?? 'unreadable',
      message: json['message'] as String?,
      paidAmount: (json['paidAmount'] as num?)?.toDouble(),
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble(),
      isDuplicate: json['isDuplicate'] as bool? ?? false,
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
    List<String> counterExpenseSplitIds = const [],
  }) async {
    final body = <String, dynamic>{
      'payee_member_id': payeeMemberId,
      'trip_id': tripId,
      'amount': amount,
      'expense_split_ids': expenseSplitIds,
    };
    if (counterExpenseSplitIds.isNotEmpty) {
      body['counter_expense_split_ids'] = counterExpenseSplitIds;
    }
    final response = await _client.post(
      '/payment/generate-qr',
      body: body,
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

  /// POST /api/payment/verify-slip - Verify parsed QR data (client-side extraction)
  Future<SlipVerificationResult> verifySlipData({
    required String settlementId,
    required double amount,
    required String receiverId,
    String? transactionRef,
    String? rawPayload,
    String? settlementToken,
  }) async {
    final response = await _client.post(
      '/payment/verify-slip',
      body: {
        'settlement_id': settlementId,
        'amount': amount,
        'receiver_id': receiverId,
        if (transactionRef != null && transactionRef.isNotEmpty)
          'transaction_ref': transactionRef,
        if (rawPayload != null && rawPayload.isNotEmpty)
          'raw_payload': rawPayload,
        if (settlementToken != null && settlementToken.isNotEmpty)
          'settlement_token': settlementToken,
      },
    );

    if (response.data is Map<String, dynamic>) {
      return SlipVerificationResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    }

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to verify slip');
    }

    throw Exception('Invalid verification response');
  }

  /// GET /api/payment/settlements/:id - Get settlement status
  Future<SettlementRecord> getSettlementStatus(String settlementId) async {
    final response = await _client.get('/payment/settlements/$settlementId');

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to get settlement status');
    }

    return SettlementRecord.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<SettlementRecord>> getTripSettlements(String tripId) async {
    final response = await _client.get('/payment/trips/$tripId/settlements');

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to load settlements');
    }

    final data = response.data as List<dynamic>;
    return data
        .map((item) => SettlementRecord.fromJson(item as Map<String, dynamic>))
        .toList();
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
