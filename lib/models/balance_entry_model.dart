/// Balance entry for "Who Owes Who" view
class BalanceEntry {
  final String memberId;
  final String? nickname;
  final String? avatarUrl;
  final String? ghostName;
  final double owes; // Amount this member owes others
  final double isOwed; // Amount owed to this member
  final double net; // net = isOwed - owes (positive = owed to them)

  const BalanceEntry({
    required this.memberId,
    this.nickname,
    this.avatarUrl,
    this.ghostName,
    required this.owes,
    required this.isOwed,
    required this.net,
  });

  /// Display name
  String get displayName => nickname ?? ghostName ?? 'Unknown';

  factory BalanceEntry.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;

    return BalanceEntry(
      memberId: json['member_id'] as String,
      nickname: profile?['nickname'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      ghostName: json['ghost_name'] as String?,
      owes: (json['owes'] as num?)?.toDouble() ?? 0,
      isOwed: (json['is_owed'] as num?)?.toDouble() ?? 0,
      net: (json['net'] as num?)?.toDouble() ?? 0,
    );
  }
}
