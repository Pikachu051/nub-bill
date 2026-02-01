import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/models/trip_model.dart';
import 'package:nubbill/services/trip_service.dart';

/// Provider for user's groups (trips from backend)
final groupsProvider = FutureProvider<List<Trip>>((ref) async {
  final service = ref.watch(tripServiceProvider);
  return service.getTrips();
});

/// Provider for refreshing groups list
final groupsRefreshProvider = Provider<void Function()>((ref) {
  return () => ref.invalidate(groupsProvider);
});
