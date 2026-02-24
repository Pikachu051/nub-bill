/// Realtime Service for Supabase live updates
///
/// Provides live subscriptions to database changes for:
/// - Expenses (live bill updates in groups)
/// - Expense splits (payment status changes)
/// - Settlements (verification status)
/// - Notifications (activity feed)
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nubbill/config/supabase_config.dart';
import 'package:nubbill/services/auth_repository.dart';

/// Realtime event types
enum RealtimeEventType { insert, update, delete }

/// Realtime event wrapper
class RealtimeEvent<T> {
  final RealtimeEventType type;
  final T? newRecord;
  final T? oldRecord;

  RealtimeEvent({required this.type, this.newRecord, this.oldRecord});
}

/// Realtime service for managing Supabase subscriptions
class RealtimeService {
  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};

  RealtimeService(this._client);

  /// Subscribe to expenses for a specific trip
  StreamSubscription<RealtimeEvent<Map<String, dynamic>>>
  subscribeToTripExpenses({
    required String tripId,
    required void Function(RealtimeEvent<Map<String, dynamic>>) onEvent,
  }) {
    final channelName = 'trip-expenses-$tripId';
    final controller =
        StreamController<RealtimeEvent<Map<String, dynamic>>>.broadcast();

    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'expenses',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (payload) {
            final eventType = _mapEventType(payload.eventType);
            controller.add(
              RealtimeEvent(
                type: eventType,
                newRecord: payload.newRecord,
                oldRecord: payload.oldRecord,
              ),
            );
          },
        )
        .subscribe();

    _channels[channelName] = channel;

    return controller.stream.listen(onEvent);
  }

  /// Subscribe to expense splits for a specific expense
  StreamSubscription<RealtimeEvent<Map<String, dynamic>>>
  subscribeToExpenseSplits({
    required String expenseId,
    required void Function(RealtimeEvent<Map<String, dynamic>>) onEvent,
  }) {
    final channelName = 'expense-splits-$expenseId';
    final controller =
        StreamController<RealtimeEvent<Map<String, dynamic>>>.broadcast();

    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'expense_splits',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'expense_id',
            value: expenseId,
          ),
          callback: (payload) {
            final eventType = _mapEventType(payload.eventType);
            controller.add(
              RealtimeEvent(
                type: eventType,
                newRecord: payload.newRecord,
                oldRecord: payload.oldRecord,
              ),
            );
          },
        )
        .subscribe();

    _channels[channelName] = channel;

    return controller.stream.listen(onEvent);
  }

  /// Subscribe to settlements for a specific trip
  StreamSubscription<RealtimeEvent<Map<String, dynamic>>>
  subscribeToTripSettlements({
    required String tripId,
    required void Function(RealtimeEvent<Map<String, dynamic>>) onEvent,
  }) {
    final channelName = 'trip-settlements-$tripId';
    final controller =
        StreamController<RealtimeEvent<Map<String, dynamic>>>.broadcast();

    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'settlements',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (payload) {
            final eventType = _mapEventType(payload.eventType);
            controller.add(
              RealtimeEvent(
                type: eventType,
                newRecord: payload.newRecord,
                oldRecord: payload.oldRecord,
              ),
            );
          },
        )
        .subscribe();

    _channels[channelName] = channel;

    return controller.stream.listen(onEvent);
  }

  /// Subscribe to notifications for current user
  StreamSubscription<RealtimeEvent<Map<String, dynamic>>>
  subscribeToNotifications({
    required void Function(RealtimeEvent<Map<String, dynamic>>) onEvent,
  }) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final channelName = 'user-notifications-$userId';
    final controller =
        StreamController<RealtimeEvent<Map<String, dynamic>>>.broadcast();

    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            controller.add(
              RealtimeEvent(
                type: RealtimeEventType.insert,
                newRecord: payload.newRecord,
              ),
            );
          },
        )
        .subscribe();

    _channels[channelName] = channel;

    return controller.stream.listen(onEvent);
  }

  /// Unsubscribe from a specific channel
  Future<void> unsubscribe(String channelName) async {
    final channel = _channels.remove(channelName);
    if (channel != null) {
      await channel.unsubscribe();
    }
  }

  /// Unsubscribe from all channels
  Future<void> unsubscribeAll() async {
    for (final channel in _channels.values) {
      await channel.unsubscribe();
    }
    _channels.clear();
  }

  /// Map Supabase event type to our enum
  RealtimeEventType _mapEventType(PostgresChangeEvent event) {
    switch (event) {
      case PostgresChangeEvent.insert:
        return RealtimeEventType.insert;
      case PostgresChangeEvent.update:
        return RealtimeEventType.update;
      case PostgresChangeEvent.delete:
        return RealtimeEventType.delete;
      default:
        return RealtimeEventType.update;
    }
  }
}

/// Provider for RealtimeService
final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  return RealtimeService(SupabaseConfig.client);
});

/// Stream provider for trip expenses (use in widgets)
final tripExpensesStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, tripId) {
      final service = ref.watch(realtimeServiceProvider);
      final controller =
          StreamController<List<Map<String, dynamic>>>.broadcast();

      // Initial empty list
      List<Map<String, dynamic>> expenses = [];
      controller.add(expenses);

      // Subscribe to realtime updates
      final subscription = service.subscribeToTripExpenses(
        tripId: tripId,
        onEvent: (event) {
          switch (event.type) {
            case RealtimeEventType.insert:
              if (event.newRecord != null) {
                expenses = [...expenses, event.newRecord!];
              }
              break;
            case RealtimeEventType.update:
              if (event.newRecord != null) {
                expenses = expenses.map((e) {
                  return e['id'] == event.newRecord!['id']
                      ? event.newRecord!
                      : e;
                }).toList();
              }
              break;
            case RealtimeEventType.delete:
              if (event.oldRecord != null) {
                expenses = expenses
                    .where((e) => e['id'] != event.oldRecord!['id'])
                    .toList();
              }
              break;
          }
          controller.add(expenses);
        },
      );

      ref.onDispose(() {
        subscription.cancel();
        controller.close();
      });

      return controller.stream;
    });

/// Stream provider for user notifications
final notificationsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final userId = ref.watch(authUserIdProvider);
      if (userId == null) {
        return Stream<List<Map<String, dynamic>>>.value([]);
      }

      final service = ref.watch(realtimeServiceProvider);
      final controller =
          StreamController<List<Map<String, dynamic>>>.broadcast();

      List<Map<String, dynamic>> notifications = [];
      controller.add(notifications);

      try {
        final subscription = service.subscribeToNotifications(
          onEvent: (event) {
            if (event.type == RealtimeEventType.insert &&
                event.newRecord != null) {
              // Add new notification at the beginning
              notifications = [event.newRecord!, ...notifications];
              controller.add(notifications);
            }
          },
        );

        ref.onDispose(() {
          subscription.cancel();
          controller.close();
        });
      } catch (e) {
        // User not authenticated, just return empty stream
        controller.add([]);
      }

      return controller.stream;
    });
