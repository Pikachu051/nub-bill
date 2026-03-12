import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nubbill/services/auth_repository.dart';

/// Emits a tick whenever the `trip_members` table changes for the current user.
/// Watch this from any FutureProvider that should auto-refresh on membership changes.
final tripMembersRealtimeProvider = StreamProvider.autoDispose<int>((ref) {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) return Stream<int>.value(0);

  final supabase = Supabase.instance.client;
  final controller = StreamController<int>.broadcast();
  var tick = 0;

  void emitTick() {
    tick += 1;
    controller.add(tick);
  }

  final channel = supabase
      .channel('trip-members-$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'trip_members',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) => emitTick(),
      )
      .subscribe();

  controller.add(tick);

  ref.onDispose(() async {
    await channel.unsubscribe();
    await controller.close();
  });

  return controller.stream;
});

/// Emits a tick whenever expenses change for a specific trip.
final tripExpensesRealtimeProvider =
    StreamProvider.autoDispose.family<int, String>((ref, tripId) {
  final supabase = Supabase.instance.client;
  final controller = StreamController<int>.broadcast();
  var tick = 0;

  void emitTick() {
    tick += 1;
    controller.add(tick);
  }

  final channel = supabase
      .channel('rt-expenses-$tripId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'expenses',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'trip_id',
          value: tripId,
        ),
        callback: (_) => emitTick(),
      )
      // expense_splits doesn't have trip_id directly, so we rely on
      // the expenses subscription above to catch most changes.
      // Only listen for split status updates (paid/unpaid) which affect balances.
      .subscribe();

  controller.add(tick);

  ref.onDispose(() async {
    await channel.unsubscribe();
    await controller.close();
  });

  return controller.stream;
});

/// Emits a tick whenever settlements change for a specific trip.
final tripSettlementsRealtimeProvider =
    StreamProvider.autoDispose.family<int, String>((ref, tripId) {
  final supabase = Supabase.instance.client;
  final controller = StreamController<int>.broadcast();
  var tick = 0;

  void emitTick() {
    tick += 1;
    controller.add(tick);
  }

  final channel = supabase
      .channel('rt-settlements-$tripId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'settlements',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'trip_id',
          value: tripId,
        ),
        callback: (_) => emitTick(),
      )
      .subscribe();

  controller.add(tick);

  ref.onDispose(() async {
    await channel.unsubscribe();
    await controller.close();
  });

  return controller.stream;
});

/// Emits a tick whenever wallet-relevant tables change.
/// Replaces the unfiltered home page subscription.
final walletRealtimeProvider = StreamProvider.autoDispose<int>((ref) {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) return Stream<int>.value(0);

  final supabase = Supabase.instance.client;
  final controller = StreamController<int>.broadcast();
  var tick = 0;

  void emitTick() {
    tick += 1;
    controller.add(tick);
  }

  // Listen to trip_members for this user (joins/leaves) and
  // use a broader trigger via expenses/settlements.
  final channel = supabase
      .channel('wallet-rt-$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'trip_members',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) => emitTick(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'expenses',
        callback: (_) => emitTick(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'settlements',
        callback: (_) => emitTick(),
      )
      .subscribe();

  controller.add(tick);

  ref.onDispose(() async {
    await channel.unsubscribe();
    await controller.close();
  });

  return controller.stream;
});
