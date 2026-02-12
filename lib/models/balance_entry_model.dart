/// Balance entry for "Who Owes Who" view
/// Matches backend response from GET /trips/:id/balances
class BalanceEntry {
  final String memberId;
  final String? userId;
  final String? name;
  final String? avatarUrl;
  final bool isGhost;
  final double totalPaid; // How much this member has paid
  final double totalOwes; // How much this member owes
  final double net; // net = totalPaid - totalOwes (positive = owed to them)

  const BalanceEntry({
    required this.memberId,
    this.userId,
    this.name,
    this.avatarUrl,
    this.isGhost = false,
    required this.totalPaid,
    required this.totalOwes,
    required this.net,
  });

  /// Display name
  String get displayName => name ?? 'Unknown';

  factory BalanceEntry.fromJson(Map<String, dynamic> json) {
    return BalanceEntry(
      memberId: json['member_id'] as String,
      userId: json['user_id'] as String?,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isGhost: json['is_ghost'] as bool? ?? false,
      totalPaid: (json['total_paid'] as num?)?.toDouble() ?? 0,
      totalOwes: (json['total_owes'] as num?)?.toDouble() ?? 0,
      net: (json['net'] as num?)?.toDouble() ?? 0,
    );
  }
}
