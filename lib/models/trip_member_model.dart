/// Trip member model matching backend TripMember with profile
class TripMember {
  final String id;
  final String tripId;
  final String? userId;
  final String role;
  final String? ghostName;
  final String? ghostPhone;
  final DateTime joinedAt;

  // Profile info (joined)
  final String? nickname;
  final String? avatarUrl;

  const TripMember({
    required this.id,
    required this.tripId,
    this.userId,
    required this.role,
    this.ghostName,
    this.ghostPhone,
    required this.joinedAt,
    this.nickname,
    this.avatarUrl,
  });

  /// Display name (nickname or ghost name)
  String get displayName => nickname ?? ghostName ?? 'Unknown';

  /// Check if this is a ghost member
  bool get isGhost => userId == null;

  factory TripMember.fromJson(Map<String, dynamic> json) {
    final rawProfiles = json['profiles'];
    Map<String, dynamic>? profiles;

    if (rawProfiles is Map<String, dynamic>) {
      profiles = rawProfiles;
    } else if (rawProfiles is List && rawProfiles.isNotEmpty) {
      final first = rawProfiles.first;
      if (first is Map<String, dynamic>) {
        profiles = first;
      }
    }

    return TripMember(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      userId: json['user_id'] as String?,
      role: json['role'] as String? ?? 'member',
      ghostName: json['ghost_name'] as String?,
      ghostPhone: json['ghost_phone'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      nickname: profiles?['nickname'] as String?,
      avatarUrl: profiles?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'user_id': userId,
      'role': role,
      'ghost_name': ghostName,
      'ghost_phone': ghostPhone,
      'joined_at': joinedAt.toIso8601String(),
    };
  }
}
