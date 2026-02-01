import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for FriendService
final friendServiceProvider = Provider<FriendService>((ref) {
  return FriendService(Supabase.instance.client);
});

/// Provider for friends list with balances
final friendsProvider = FutureProvider<List<Friend>>((ref) async {
  final service = ref.read(friendServiceProvider);
  return service.getFriends();
});

/// Provider for pending friend requests
final pendingRequestsProvider = FutureProvider<PendingRequests>((ref) async {
  final service = ref.read(friendServiceProvider);
  return service.getPendingRequests();
});

/// Friend model with cross-group balance
class Friend {
  final String id;
  final String nickname;
  final String? email;
  final String? avatarUrl;
  final double balance;
  final int sharedTripsCount;

  Friend({
    required this.id,
    required this.nickname,
    this.email,
    this.avatarUrl,
    required this.balance,
    required this.sharedTripsCount,
  });
}

/// Pending friend request
class FriendRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final String? requesterAvatarUrl;
  final DateTime createdAt;

  FriendRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    this.requesterAvatarUrl,
    required this.createdAt,
  });
}

/// Container for pending requests
class PendingRequests {
  final List<FriendRequest> incoming;
  final List<Map<String, dynamic>> outgoing;

  PendingRequests({required this.incoming, required this.outgoing});
}

/// Search result for users
class UserSearchResult {
  final String id;
  final String nickname;
  final String? email;
  final String? avatarUrl;
  final String? friendshipStatus;
  final bool isPendingFromMe;

  UserSearchResult({
    required this.id,
    required this.nickname,
    this.email,
    this.avatarUrl,
    this.friendshipStatus,
    this.isPendingFromMe = false,
  });
}

/// Service for Friend operations using Supabase directly
/// Schema: friendships table has user_a, user_b (ordered), initiated_by, status
/// References profiles table (not users)
class FriendService {
  final SupabaseClient _supabase;

  FriendService(this._supabase);

  String get _userId => _supabase.auth.currentUser!.id;

  /// Get list of friends with balances
  Future<List<Friend>> getFriends() async {
    // Get all accepted friendships where current user is user_a or user_b
    final friendships = await _supabase
        .from('friendships')
        .select('id, user_a, user_b, status, initiated_by')
        .or('user_a.eq.$_userId,user_b.eq.$_userId')
        .eq('status', 'accepted');

    final List<Friend> friends = [];

    for (final f in friendships) {
      // Determine who is the friend (the other person)
      final friendId = f['user_a'] == _userId ? f['user_b'] : f['user_a'];

      // Get friend's profile
      final profile = await _supabase
          .from('profiles')
          .select('id, nickname, email, avatar_url')
          .eq('id', friendId)
          .maybeSingle();

      if (profile != null) {
        // Count shared trips
        final sharedTrips = await _countSharedTrips(friendId);

        friends.add(
          Friend(
            id: friendId,
            nickname: profile['nickname'] ?? 'Unknown',
            email: profile['email'],
            avatarUrl: profile['avatar_url'],
            balance: 0, // Simplified - would need expense calculations
            sharedTripsCount: sharedTrips,
          ),
        );
      }
    }

    return friends;
  }

  Future<int> _countSharedTrips(String friendId) async {
    try {
      final myTrips = await _supabase
          .from('trip_members')
          .select('trip_id')
          .eq('user_id', _userId);

      final myTripIds = (myTrips as List).map((t) => t['trip_id']).toList();

      if (myTripIds.isEmpty) return 0;

      final sharedTrips = await _supabase
          .from('trip_members')
          .select('trip_id')
          .eq('user_id', friendId)
          .inFilter('trip_id', myTripIds);

      return (sharedTrips as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Get pending friend requests
  Future<PendingRequests> getPendingRequests() async {
    // Incoming requests (where I'm user_a or user_b, but NOT initiated_by me)
    final allPending = await _supabase
        .from('friendships')
        .select('id, user_a, user_b, initiated_by, created_at')
        .or('user_a.eq.$_userId,user_b.eq.$_userId')
        .eq('status', 'pending');

    final List<FriendRequest> incoming = [];
    final List<Map<String, dynamic>> outgoing = [];

    for (final req in allPending) {
      final isInitiator = req['initiated_by'] == _userId;
      final otherId = req['user_a'] == _userId ? req['user_b'] : req['user_a'];

      // Get other person's profile
      final profile = await _supabase
          .from('profiles')
          .select('id, nickname, avatar_url')
          .eq('id', otherId)
          .maybeSingle();

      if (isInitiator) {
        // Outgoing request
        outgoing.add({
          'id': req['id'],
          'created_at': req['created_at'],
          'target': profile,
        });
      } else {
        // Incoming request
        incoming.add(
          FriendRequest(
            id: req['id'],
            requesterId: req['initiated_by'],
            requesterName: profile?['nickname'] ?? 'Unknown',
            requesterAvatarUrl: profile?['avatar_url'],
            createdAt: DateTime.parse(req['created_at']),
          ),
        );
      }
    }

    return PendingRequests(incoming: incoming, outgoing: outgoing);
  }

  /// Search users by email or nickname
  Future<List<UserSearchResult>> searchUsers(String query) async {
    final results = await _supabase
        .from('profiles')
        .select('id, nickname, email, avatar_url')
        .or('nickname.ilike.%$query%,email.ilike.%$query%')
        .neq('id', _userId)
        .limit(20);

    final List<UserSearchResult> searchResults = [];

    for (final user in results) {
      final friendshipStatus = await _checkFriendshipStatus(user['id']);

      searchResults.add(
        UserSearchResult(
          id: user['id'],
          nickname: user['nickname'] ?? 'Unknown',
          email: user['email'],
          avatarUrl: user['avatar_url'],
          friendshipStatus: friendshipStatus['status'],
          isPendingFromMe: friendshipStatus['isPendingFromMe'] ?? false,
        ),
      );
    }

    return searchResults;
  }

  Future<Map<String, dynamic>> _checkFriendshipStatus(String otherId) async {
    // Ensure user_a < user_b for the query (schema constraint)
    final userA = _userId.compareTo(otherId) < 0 ? _userId : otherId;
    final userB = _userId.compareTo(otherId) < 0 ? otherId : _userId;

    final friendship = await _supabase
        .from('friendships')
        .select('status, initiated_by')
        .eq('user_a', userA)
        .eq('user_b', userB)
        .maybeSingle();

    if (friendship == null) {
      return {'status': null, 'isPendingFromMe': false};
    }

    return {
      'status': friendship['status'],
      'isPendingFromMe': friendship['initiated_by'] == _userId,
    };
  }

  /// Send friend request by user ID
  Future<void> sendRequestById(String otherId) async {
    // Ensure user_a < user_b (schema constraint)
    final userA = _userId.compareTo(otherId) < 0 ? _userId : otherId;
    final userB = _userId.compareTo(otherId) < 0 ? otherId : _userId;

    // Check if friendship already exists
    final existing = await _supabase
        .from('friendships')
        .select('id')
        .eq('user_a', userA)
        .eq('user_b', userB)
        .maybeSingle();

    if (existing != null) {
      throw Exception('มีคำขอหรือเป็นเพื่อนอยู่แล้ว');
    }

    await _supabase.from('friendships').insert({
      'user_a': userA,
      'user_b': userB,
      'initiated_by': _userId,
      'status': 'pending',
    });
  }

  /// Accept friend request
  Future<void> acceptRequest(String requesterId) async {
    final userA = _userId.compareTo(requesterId) < 0 ? _userId : requesterId;
    final userB = _userId.compareTo(requesterId) < 0 ? requesterId : _userId;

    await _supabase
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('user_a', userA)
        .eq('user_b', userB)
        .eq('initiated_by', requesterId)
        .eq('status', 'pending');
  }

  /// Reject friend request
  Future<void> rejectRequest(String requesterId) async {
    final userA = _userId.compareTo(requesterId) < 0 ? _userId : requesterId;
    final userB = _userId.compareTo(requesterId) < 0 ? requesterId : _userId;

    await _supabase
        .from('friendships')
        .delete()
        .eq('user_a', userA)
        .eq('user_b', userB)
        .eq('initiated_by', requesterId)
        .eq('status', 'pending');
  }

  /// Remove friend
  Future<void> removeFriend(String friendId) async {
    final userA = _userId.compareTo(friendId) < 0 ? _userId : friendId;
    final userB = _userId.compareTo(friendId) < 0 ? friendId : _userId;

    await _supabase
        .from('friendships')
        .delete()
        .eq('user_a', userA)
        .eq('user_b', userB);
  }

  /// Send friend request by email
  Future<void> sendRequestByEmail(String email) async {
    final user = await _supabase
        .from('profiles')
        .select('id')
        .eq('email', email)
        .maybeSingle();

    if (user == null) {
      throw Exception('ไม่พบผู้ใช้ที่มีอีเมลนี้');
    }

    await sendRequestById(user['id']);
  }
}
