class SettlementRecord {
  final String id;
  final String payerMemberId;
  final String payeeMemberId;
  final String tripId;
  final double amount;
  final List<String> expenseSplitIds;
  final List<String> counterExpenseSplitIds;
  final String? slipImageUrl;
  final Map<String, dynamic>? slipData;
  final String status;
  final String? rejectionReason;
  final String createdAt;
  final String updatedAt;
  final SettlementMember? payer;
  final SettlementMember? payee;

  const SettlementRecord({
    required this.id,
    required this.payerMemberId,
    required this.payeeMemberId,
    required this.tripId,
    required this.amount,
    this.expenseSplitIds = const [],
    this.counterExpenseSplitIds = const [],
    this.slipImageUrl,
    this.slipData,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.payer,
    this.payee,
  });

  bool get isVerified => status == 'verified';

  String? get transactionRef => slipData?['transaction_ref'] as String?;

  bool get isPartialPayment => slipData?['partial_payment'] == true;

  double get paidAmount =>
      (slipData?['amount'] as num?)?.toDouble() ?? amount;

  double? get remainingAmount =>
      (slipData?['remaining_amount'] as num?)?.toDouble();

  DateTime? get verifiedAt {
    final value =
        slipData?['verified_at'] ?? slipData?['manual_verified_at'] ?? updatedAt;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return DateTime.tryParse(updatedAt);
  }

  bool referencesSplitId(String splitId) {
    return expenseSplitIds.contains(splitId) ||
        counterExpenseSplitIds.contains(splitId);
  }

  factory SettlementRecord.fromJson(Map<String, dynamic> json) {
    final slipData = json['slip_data'];
    return SettlementRecord(
      id: json['id'] as String,
      payerMemberId: json['payer_member_id'] as String,
      payeeMemberId: json['payee_member_id'] as String,
      tripId: json['trip_id'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      expenseSplitIds: ((json['expense_split_ids'] as List<dynamic>?) ?? [])
          .map((value) => value as String)
          .toList(),
      counterExpenseSplitIds:
          ((json['counter_expense_split_ids'] as List<dynamic>?) ?? [])
              .map((value) => value as String)
              .toList(),
      slipImageUrl: json['slip_image_url'] as String?,
      slipData: slipData is Map<String, dynamic>
          ? slipData
          : (slipData is Map ? Map<String, dynamic>.from(slipData) : null),
      status: json['status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      payer: json['payer'] is Map<String, dynamic>
          ? SettlementMember.fromJson(json['payer'] as Map<String, dynamic>)
          : null,
      payee: json['payee'] is Map<String, dynamic>
          ? SettlementMember.fromJson(json['payee'] as Map<String, dynamic>)
          : null,
    );
  }
}

class SettlementMember {
  final String? userId;
  final String? ghostName;
  final String? nickname;
  final String? avatarUrl;

  const SettlementMember({
    this.userId,
    this.ghostName,
    this.nickname,
    this.avatarUrl,
  });

  String get displayName => nickname ?? ghostName ?? 'Unknown';

  factory SettlementMember.fromJson(Map<String, dynamic> json) {
    final profiles = json['profiles'] as Map<String, dynamic>?;
    return SettlementMember(
      userId: json['user_id'] as String?,
      ghostName: json['ghost_name'] as String?,
      nickname: profiles?['nickname'] as String?,
      avatarUrl: profiles?['avatar_url'] as String?,
    );
  }
}
