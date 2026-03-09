import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/config/api_config.dart';
import 'package:nubbill/models/trip_model.dart';
import 'package:nubbill/models/trip_member_model.dart';
import 'package:nubbill/models/balance_entry_model.dart';
import 'package:nubbill/models/debt_entry_model.dart';
import 'package:nubbill/services/auth_repository.dart';

/// Provider for TripService
final tripServiceProvider = Provider<TripService>((ref) {
  return TripService(ApiClient());
});

/// Provider for trips list (auto-refresh)
final tripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) return [];

  final service = ref.read(tripServiceProvider);
  return service.getTrips();
});

/// Provider for a specific trip detail
final tripDetailProvider = FutureProvider.autoDispose
    .family<TripDetailResponse?, String>((ref, tripId) async {
      final userId = ref.watch(authUserIdProvider);
      if (userId == null) return null;

      final service = ref.read(tripServiceProvider);
      return service.getTripDetail(tripId);
    });

/// Provider for trip balances (who owes who)
final tripBalancesProvider = FutureProvider.autoDispose
    .family<List<BalanceEntry>, String>((ref, tripId) async {
      final userId = ref.watch(authUserIdProvider);
      if (userId == null) return [];

      final service = ref.read(tripServiceProvider);
      return service.getTripBalances(tripId);
    });

/// Provider for simplified pairwise debts
final tripDebtsProvider = FutureProvider.autoDispose
    .family<List<DebtEntry>, String>((ref, tripId) async {
      final userId = ref.watch(authUserIdProvider);
      if (userId == null) return [];

      final service = ref.read(tripServiceProvider);
      return service.getTripDebts(tripId);
    });

/// Trip detail response containing trip, members, and role
class TripDetailResponse {
  final Trip trip;
  final List<TripMember> members;
  final String myRole;
  final String? myMemberId;

  TripDetailResponse({
    required this.trip,
    required this.members,
    required this.myRole,
    this.myMemberId,
  });

  factory TripDetailResponse.fromJson(Map<String, dynamic> json) {
    final tripData = json['trip'] as Map<String, dynamic>;
    final membersData = json['members'] as List<dynamic>? ?? [];

    return TripDetailResponse(
      trip: Trip.fromJson(tripData),
      members: membersData
          .map((m) => TripMember.fromJson(m as Map<String, dynamic>))
          .toList(),
      myRole: json['my_role'] as String? ?? 'member',
      myMemberId: json['my_member_id'] as String?,
    );
  }
}

/// Service for Trip (Group) API calls
class TripService {
  final ApiClient _client;

  TripService(this._client);

  /// GET /api/trips - List user's trips
  Future<List<Trip>> getTrips() async {
    final response = await _client.get('/trips');

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to load trips');
    }

    final data = response.data as List<dynamic>;
    return data.map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/trips - Create new trip
  Future<Trip> createTrip({
    required String name,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? memberIds,
  }) async {
    final body = <String, dynamic>{'name': name};

    if (category != null) {
      body['category'] = category;
    }
    if (startDate != null) {
      body['start_date'] = startDate.toIso8601String().split('T')[0];
    }
    if (endDate != null) {
      body['end_date'] = endDate.toIso8601String().split('T')[0];
    }
    if (memberIds != null && memberIds.isNotEmpty) {
      body['member_ids'] = memberIds;
    }

    final response = await _client.post('/trips', body: body);

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to create trip');
    }

    return Trip.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /api/trips/:id - Get trip details with members
  Future<TripDetailResponse?> getTripDetail(String tripId) async {
    final response = await _client.get('/trips/$tripId');

    if (response.statusCode == 404) {
      return null;
    }

    if (!response.isSuccess || response.data == null) {
      final status = response.statusCode;
      final message = response.error;
      if (message != null && message.isNotEmpty) {
        throw Exception(message);
      }
      throw Exception(
        status != null
            ? 'Failed to load trip details (HTTP $status)'
            : 'Failed to load trip details',
      );
    }

    return TripDetailResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /api/trips/join - Join trip via code
  Future<String> joinTripByCode(String code) async {
    final raw = code.trim();
    final extracted = RegExp(r'join/([A-Za-z0-9]{4,20})', caseSensitive: false)
            .firstMatch(raw)
            ?.group(1) ??
        raw;
    final normalized = extracted.toUpperCase().replaceAll(RegExp(r'\s+'), '');

    final response = await _client.post('/trips/join', body: {'code': normalized});

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to join trip');
    }

    return response.data['trip_id'] as String;
  }

  /// PATCH /api/trips/:id - Update trip
  Future<Trip> updateTrip(
    String tripId, {
    String? name,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final body = <String, dynamic>{};

    if (name != null) {
      body['name'] = name;
    }
    if (category != null) {
      body['category'] = category;
    }
    if (startDate != null) {
      body['start_date'] = startDate.toIso8601String().split('T')[0];
    }
    if (endDate != null) {
      body['end_date'] = endDate.toIso8601String().split('T')[0];
    }

    final response = await _client.patch('/trips/$tripId', body: body);

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to update trip');
    }

    return Trip.fromJson(response.data as Map<String, dynamic>);
  }

  /// DELETE /api/trips/:id - Delete trip
  Future<void> deleteTrip(String tripId) async {
    final response = await _client.delete('/trips/$tripId');

    if (!response.isSuccess) {
      throw Exception(response.error ?? 'Failed to delete trip');
    }
  }

  /// GET /api/trips/:id/balances - Get who owes who
  Future<List<BalanceEntry>> getTripBalances(String tripId) async {
    final response = await _client.get('/trips/$tripId/balances');

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to load balances');
    }

    final data = response.data as List<dynamic>;
    return data
        .map((e) => BalanceEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/trips/:id/debts - Get simplified pairwise debts
  Future<List<DebtEntry>> getTripDebts(String tripId) async {
    final response = await _client.get('/trips/$tripId/debts');

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to load debts');
    }

    final data = response.data as List<dynamic>;
    return data
        .map((e) => DebtEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/trips/:id/members - Add members to trip
  Future<void> addMembers(
    String tripId, {
    List<String>? userIds,
    List<Map<String, String>>? ghosts,
  }) async {
    final body = <String, dynamic>{};

    if (userIds != null && userIds.isNotEmpty) body['user_ids'] = userIds;
    if (ghosts != null && ghosts.isNotEmpty) body['ghosts'] = ghosts;

    final response = await _client.post('/trips/$tripId/members', body: body);

    if (!response.isSuccess) {
      throw Exception(response.error ?? 'Failed to add members');
    }
  }

  /// DELETE /api/trips/:id/members/:memberId - Remove member
  Future<void> removeMember(String tripId, String memberId) async {
    final response = await _client.delete('/trips/$tripId/members/$memberId');

    if (!response.isSuccess) {
      throw Exception(response.error ?? 'Failed to remove member');
    }
  }

  /// POST /api/trips/:id/members/:memberId/make-admin - Grant admin role
  Future<void> makeAdmin(String tripId, String memberId) async {
    final response = await _client.post(
      '/trips/$tripId/members/$memberId/make-admin',
    );

    if (!response.isSuccess) {
      throw Exception(response.error ?? 'Failed to grant admin role');
    }
  }

  /// POST /api/trips/:id/leave - Leave trip
  Future<void> leaveTrip(String tripId) async {
    final response = await _client.post('/trips/$tripId/leave');

    if (!response.isSuccess) {
      throw Exception(response.error ?? 'Failed to leave trip');
    }
  }

  /// POST /api/trips/:id/cover - Upload trip cover image
  Future<String> uploadCover(String tripId, List<int> imageBytes) async {
    final response = await _client.uploadFile(
      '/trips/$tripId/cover',
      imageBytes,
      'cover.jpg',
    );

    if (!response.isSuccess || response.data == null) {
      throw Exception(response.error ?? 'Failed to upload cover');
    }

    return response.data['cover_url'] as String;
  }
}
