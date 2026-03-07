/// Simplified pairwise debt entry from GET /trips/:id/debts
/// Represents: fromMember owes toMember the given amount
class DebtEntry {
  final String fromMemberId;
  final String fromName;
  final String? fromAvatarUrl;
  final String? fromUserId;
  final String toMemberId;
  final String toName;
  final String? toAvatarUrl;
  final String? toUserId;
  final double amount;
  final List<String> expenseSplitIds;
  final List<String> counterExpenseSplitIds;

  const DebtEntry({
    required this.fromMemberId,
    required this.fromName,
    this.fromAvatarUrl,
    this.fromUserId,
    required this.toMemberId,
    required this.toName,
    this.toAvatarUrl,
    this.toUserId,
    required this.amount,
    this.expenseSplitIds = const [],
    this.counterExpenseSplitIds = const [],
  });

  factory DebtEntry.fromJson(Map<String, dynamic> json) {
    return DebtEntry(
      fromMemberId: json['from_member_id'] as String,
      fromName: json['from_name'] as String? ?? 'Unknown',
      fromAvatarUrl: json['from_avatar_url'] as String?,
      fromUserId: json['from_user_id'] as String?,
      toMemberId: json['to_member_id'] as String,
      toName: json['to_name'] as String? ?? 'Unknown',
      toAvatarUrl: json['to_avatar_url'] as String?,
      toUserId: json['to_user_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      expenseSplitIds: (json['expense_split_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      counterExpenseSplitIds: (json['counter_expense_split_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
