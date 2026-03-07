import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nubbill/config/api_config.dart';
import 'package:nubbill/config/supabase_config.dart';
import 'package:nubbill/models/notification_model.dart';
import 'package:nubbill/services/auth_repository.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class NotificationState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;
  final int unreadCount;
  final bool hasMore;
  final int page;

  const NotificationState({
    required this.notifications,
    required this.isLoading,
    this.error,
    required this.unreadCount,
    required this.hasMore,
    required this.page,
  });

  factory NotificationState.initial() => const NotificationState(
        notifications: [],
        isLoading: false,
        unreadCount: 0,
        hasMore: true,
        page: 1,
      );

  NotificationState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    String? error,
    int? unreadCount,
    bool? hasMore,
    int? page,
    bool clearError = false,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      unreadCount: unreadCount ?? this.unreadCount,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class NotificationNotifier extends StateNotifier<NotificationState> {
  final ApiClient _client;
  final SupabaseClient _supabase;
  final String? _userId;
  RealtimeChannel? _channel;

  NotificationNotifier(this._client, this._supabase, this._userId)
      : super(NotificationState.initial()) {
    if (_userId != null) {
      _load();
      _subscribe();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (state.isLoading) return;

    final page = refresh ? 1 : state.page;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _client.get('/notifications?page=$page&limit=20');

      if (!response.isSuccess) {
        state = state.copyWith(isLoading: false, error: 'โหลดการแจ้งเตือนไม่สำเร็จ');
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final raw = (data['notifications'] as List<dynamic>?) ?? [];
      final fetched = raw
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();

      final existing = refresh ? <AppNotification>[] : state.notifications;
      // Deduplicate by id so realtime prepends don't duplicate on refresh
      final existingIds = existing.map((n) => n.id).toSet();
      final merged = [
        ...existing,
        ...fetched.where((n) => !existingIds.contains(n.id)),
      ];

      state = state.copyWith(
        notifications: merged,
        isLoading: false,
        unreadCount: (data['unread_count'] as int?) ?? state.unreadCount,
        hasMore: (data['has_more'] as bool?) ?? false,
        page: page + 1,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _subscribe() {
    _channel = _supabase
        .channel('notifications-feed-$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId!,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final notification = AppNotification.fromJson(row);
            state = state.copyWith(
              notifications: [notification, ...state.notifications],
              unreadCount: state.unreadCount + 1,
            );
          },
        )
        .subscribe();
  }

  Future<void> refresh() => _load(refresh: true);

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    await _load();
  }

  Future<void> markRead(String id) async {
    try {
      final response = await _client.patch('/notifications/$id/read');
      if (response.isSuccess) {
        final updated = state.notifications.map((n) {
          return n.id == id ? n.copyWith(isRead: true) : n;
        }).toList();
        final wasUnread = state.notifications.any((n) => n.id == id && !n.isRead);
        state = state.copyWith(
          notifications: updated,
          unreadCount:
              wasUnread ? (state.unreadCount - 1).clamp(0, 9999) : state.unreadCount,
        );
      }
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      final response = await _client.post('/notifications/read-all');
      if (response.isSuccess) {
        final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
        state = state.copyWith(notifications: updated, unreadCount: 0);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final userId = ref.watch(authUserIdProvider);
  return NotificationNotifier(
    ApiClient(),
    SupabaseConfig.client,
    userId,
  );
});

/// Unread notification count for nav-bar badge
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).unreadCount;
});
