/// Detailed expense model for GET /expenses/:id response
/// Includes payer profile, splits with member profiles, and expense items
class ExpenseDetail {
  final String id;
  final String tripId;
  final String payerId;
  final double amount;
  final String description;
  final String expenseDate;
  final String splitType;
  final double serviceChargePercent;
  final double vatPercent;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final String? receiptUrl;

  // Payer with full profile
  final ExpenseDetailPayer? payer;

  // Splits with member profiles
  final List<ExpenseDetailSplit> splits;

  // Items (for itemized bills)
  final List<ExpenseDetailItem> items;

  const ExpenseDetail({
    required this.id,
    required this.tripId,
    required this.payerId,
    required this.amount,
    required this.description,
    required this.expenseDate,
    this.splitType = 'equal',
    this.serviceChargePercent = 0,
    this.vatPercent = 0,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.receiptUrl,
    this.payer,
    this.splits = const [],
    this.items = const [],
  });

  factory ExpenseDetail.fromJson(Map<String, dynamic> json) {
    // Parse payer
    ExpenseDetailPayer? payer;
    if (json['payer'] != null) {
      payer = ExpenseDetailPayer.fromJson(
        json['payer'] as Map<String, dynamic>,
      );
    }

    // Parse splits
    final splitsJson = json['expense_splits'] as List<dynamic>? ?? [];
    final splits = splitsJson
        .map((s) => ExpenseDetailSplit.fromJson(s as Map<String, dynamic>))
        .toList();

    // Parse items
    final itemsJson = json['expense_items'] as List<dynamic>? ?? [];
    final items = itemsJson
        .map((i) => ExpenseDetailItem.fromJson(i as Map<String, dynamic>))
        .toList();

    return ExpenseDetail(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      payerId: json['payer_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String? ?? '',
      expenseDate: json['expense_date'] as String? ?? '',
      splitType: json['split_type'] as String? ?? 'equal',
      serviceChargePercent:
          (json['service_charge_percent'] as num?)?.toDouble() ?? 0,
      vatPercent: (json['vat_percent'] as num?)?.toDouble() ?? 0,
      createdBy: json['created_by'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      receiptUrl: json['receipt_url'] as String?,
      payer: payer,
      splits: splits,
      items: items,
    );
  }
}

/// Payer profile from the detail response
class ExpenseDetailPayer {
  final String id; // member ID
  final String? userId;
  final String? ghostName;
  final String? nickname;
  final String? avatarUrl;

  const ExpenseDetailPayer({
    required this.id,
    this.userId,
    this.ghostName,
    this.nickname,
    this.avatarUrl,
  });

  String get displayName => nickname ?? ghostName ?? 'Unknown';

  factory ExpenseDetailPayer.fromJson(Map<String, dynamic> json) {
    final profiles = json['profiles'] as Map<String, dynamic>?;
    return ExpenseDetailPayer(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      ghostName: json['ghost_name'] as String?,
      nickname: profiles?['nickname'] as String?,
      avatarUrl: profiles?['avatar_url'] as String?,
    );
  }
}

/// Split entry with member profile for the detail view
class ExpenseDetailSplit {
  final String id;
  final String memberId;
  final double amount;
  final String status; // unpaid, pending, paid

  // Member profile info
  final String? memberName;
  final String? memberAvatarUrl;
  final String? memberUserId;
  final String? memberGhostName;

  const ExpenseDetailSplit({
    required this.id,
    required this.memberId,
    required this.amount,
    required this.status,
    this.memberName,
    this.memberAvatarUrl,
    this.memberUserId,
    this.memberGhostName,
  });

  String get displayName => memberName ?? memberGhostName ?? 'Unknown';

  factory ExpenseDetailSplit.fromJson(Map<String, dynamic> json) {
    // Parse nested member -> profiles
    final member = json['member'] as Map<String, dynamic>?;
    final profiles = member?['profiles'] as Map<String, dynamic>?;

    return ExpenseDetailSplit(
      id: json['id'] as String,
      memberId: json['member_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String? ?? 'unpaid',
      memberName: profiles?['nickname'] as String?,
      memberAvatarUrl: profiles?['avatar_url'] as String?,
      memberUserId: member?['user_id'] as String?,
      memberGhostName: member?['ghost_name'] as String?,
    );
  }
}

/// Item in an itemized expense
class ExpenseDetailItem {
  final String id;
  final String name;
  final double amount;
  final int quantity;
  final List<String> sharedByMemberIds;

  const ExpenseDetailItem({
    required this.id,
    required this.name,
    required this.amount,
    this.quantity = 1,
    this.sharedByMemberIds = const [],
  });

  factory ExpenseDetailItem.fromJson(Map<String, dynamic> json) {
    // Parse shared-by member IDs
    final shares = json['expense_item_shares'] as List<dynamic>? ?? [];
    final sharedByIds = shares
        .map((s) => (s as Map<String, dynamic>)['member_id'] as String)
        .toList();

    return ExpenseDetailItem(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      quantity: json['quantity'] as int? ?? 1,
      sharedByMemberIds: sharedByIds,
    );
  }
}
