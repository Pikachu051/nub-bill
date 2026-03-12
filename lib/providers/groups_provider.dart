import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/models/trip_model.dart';
import 'package:nubbill/services/auth_repository.dart';
import 'package:nubbill/services/trip_service.dart';
import 'package:nubbill/shared/providers/realtime_invalidator.dart';

/// Provider for user's groups (trips from backend).
/// Auto-refreshes when trip_members table changes for this user.
final groupsProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) return [];

  // Watch realtime tick so we auto-refresh on membership changes.
  ref.watch(tripMembersRealtimeProvider);

  final service = ref.watch(tripServiceProvider);
  return service.getTrips();
});

/// Provider for refreshing groups list
final groupsRefreshProvider = Provider<void Function()>((ref) {
  return () => ref.invalidate(groupsProvider);
});
