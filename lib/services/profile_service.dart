import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nubbill/services/auth_repository.dart';

/// Provider for ProfileService
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(Supabase.instance.client);
});

/// Provider for current user profile
final myProfileProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) {
    throw Exception('User not authenticated');
  }

  final service = ref.read(profileServiceProvider);
  return service.getMyProfile();
});

/// User profile with stats
class UserProfile {
  final String id;
  final String? nickname;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final DateTime createdAt;
  final ProfileStats stats;
  final PaymentMethod? primaryPaymentMethod;

  UserProfile({
    required this.id,
    this.nickname,
    this.email,
    this.phone,
    this.avatarUrl,
    required this.createdAt,
    required this.stats,
    this.primaryPaymentMethod,
  });
}

/// User profile statistics
class ProfileStats {
  final int totalTrips;
  final int totalExpenses;
  final int totalFriends;
  final double totalReceived;
  final double totalPaid;
  final double netBalance;

  ProfileStats({
    required this.totalTrips,
    required this.totalExpenses,
    required this.totalFriends,
    required this.totalReceived,
    required this.totalPaid,
    required this.netBalance,
  });

  factory ProfileStats.empty() {
    return ProfileStats(
      totalTrips: 0,
      totalExpenses: 0,
      totalFriends: 0,
      totalReceived: 0,
      totalPaid: 0,
      netBalance: 0,
    );
  }
}

/// Payment method model
class PaymentMethod {
  final String id;
  final String type;
  final String promptpayId;
  final String? promptpayName;
  final bool isPrimary;

  PaymentMethod({
    required this.id,
    required this.type,
    required this.promptpayId,
    this.promptpayName,
    required this.isPrimary,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'promptpay',
      promptpayId: json['promptpay_id'] as String? ?? '',
      promptpayName: json['display_name'] as String?,
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}

/// Service for Profile operations using Supabase directly
/// Schema uses `profiles` table (not users)
class ProfileService {
  final SupabaseClient _supabase;

  ProfileService(this._supabase);

  String get _userId => _supabase.auth.currentUser!.id;

  /// Get current user profile with stats
  Future<UserProfile> getMyProfile() async {
    // Get user profile from profiles table
    final userData = await _supabase
        .from('profiles')
        .select('*')
        .eq('id', _userId)
        .single();

    // Get stats
    final stats = await _getProfileStats();

    // Get primary payment method
    final paymentMethod = await _getPrimaryPaymentMethod();

    return UserProfile(
      id: userData['id'],
      nickname: userData['nickname'],
      email: userData['email'],
      phone: userData['phone_e164'],
      avatarUrl: userData['avatar_url'],
      createdAt: DateTime.parse(
        userData['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      stats: stats,
      primaryPaymentMethod: paymentMethod,
    );
  }

  Future<ProfileStats> _getProfileStats() async {
    try {
      // Count trips
      final trips = await _supabase
          .from('trip_members')
          .select('trip_id')
          .eq('user_id', _userId);
      final totalTrips = (trips as List).length;

      // Count expenses (where user is payer via trip_members)
      int totalExpenses = 0;
      try {
        // Get member IDs for this user
        final memberIds = await _supabase
            .from('trip_members')
            .select('id')
            .eq('user_id', _userId);

        if ((memberIds as List).isNotEmpty) {
          final ids = memberIds.map((m) => m['id']).toList();
          final expenses = await _supabase
              .from('expenses')
              .select('id')
              .inFilter('payer_id', ids);
          totalExpenses = (expenses as List).length;
        }
      } catch (_) {}

      // Count friends
      final friends = await _supabase
          .from('friendships')
          .select('id')
          .or('user_a.eq.$_userId,user_b.eq.$_userId')
          .eq('status', 'accepted');
      final totalFriends = (friends as List).length;

      // Calculate settlements (simplified)
      double totalReceived = 0;
      double totalPaid = 0;

      return ProfileStats(
        totalTrips: totalTrips,
        totalExpenses: totalExpenses,
        totalFriends: totalFriends,
        totalReceived: totalReceived,
        totalPaid: totalPaid,
        netBalance: totalReceived - totalPaid,
      );
    } catch (e) {
      return ProfileStats.empty();
    }
  }

  Future<PaymentMethod?> _getPrimaryPaymentMethod() async {
    try {
      final method = await _supabase
          .from('payment_methods')
          .select('*')
          .eq('user_id', _userId)
          .eq('is_primary', true)
          .maybeSingle();

      if (method == null) return null;
      return PaymentMethod.fromJson(method);
    } catch (_) {
      return null;
    }
  }

  /// Update profile
  Future<UserProfile> updateProfile({String? nickname, String? phone}) async {
    final updates = <String, dynamic>{};
    if (nickname != null) updates['nickname'] = nickname;
    if (phone != null) updates['phone_e164'] = phone;

    await _supabase.from('profiles').update(updates).eq('id', _userId);

    return getMyProfile();
  }

  /// Get payment methods
  Future<List<PaymentMethod>> getPaymentMethods() async {
    final methods = await _supabase
        .from('payment_methods')
        .select('*')
        .eq('user_id', _userId)
        .order('is_primary', ascending: false);

    return (methods as List).map((e) => PaymentMethod.fromJson(e)).toList();
  }

  /// Add payment method
  Future<PaymentMethod> addPaymentMethod({
    required String promptpayId,
    String? displayName,
  }) async {
    // Check if any payment methods exist
    final existing = await _supabase
        .from('payment_methods')
        .select('id')
        .eq('user_id', _userId);

    final isPrimary = (existing as List).isEmpty;

    final result = await _supabase
        .from('payment_methods')
        .insert({
          'user_id': _userId,
          'type': 'promptpay',
          'promptpay_id': promptpayId,
          'display_name': displayName ?? 'PromptPay',
          'is_primary': isPrimary,
        })
        .select()
        .single();

    return PaymentMethod.fromJson(result);
  }

  /// Delete payment method
  Future<void> deletePaymentMethod(String id) async {
    await _supabase
        .from('payment_methods')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  /// Set as primary payment method
  Future<void> setPrimaryPaymentMethod(String id) async {
    // First, unset all as not primary
    await _supabase
        .from('payment_methods')
        .update({'is_primary': false})
        .eq('user_id', _userId);

    // Then set the selected one as primary
    await _supabase
        .from('payment_methods')
        .update({'is_primary': true})
        .eq('id', id)
        .eq('user_id', _userId);
  }
}
