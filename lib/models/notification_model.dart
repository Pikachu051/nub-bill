import 'package:flutter/material.dart';

enum NotificationType {
  expenseCreated,
  expenseUpdated,
  expenseDeleted,
  settlementPending,
  settlementVerified,
  settlementRejected,
  settlementNeedReview,
  manualDebtorReminder,
  friendRequest,
  friendAccepted,
  tripInvited,
  tripJoined,
  unknown;

  static NotificationType fromString(String value) {
    return switch (value) {
      'expense_created' => expenseCreated,
      'expense_updated' => expenseUpdated,
      'expense_deleted' => expenseDeleted,
      'settlement_pending' => settlementPending,
      'settlement_verified' => settlementVerified,
      'settlement_rejected' => settlementRejected,
      'settlement_need_review' => settlementNeedReview,
      'manual_debtor_reminder' => manualDebtorReminder,
      'friend_request' => friendRequest,
      'friend_accepted' => friendAccepted,
      'trip_invited' => tripInvited,
      'trip_joined' => tripJoined,
      _ => unknown,
    };
  }

  IconData get icon => switch (this) {
        expenseCreated => Icons.receipt_long,
        expenseUpdated => Icons.edit,
        expenseDeleted => Icons.delete_outline,
        settlementPending => Icons.send,
        settlementVerified => Icons.check_circle_outline,
        settlementRejected => Icons.cancel,
        settlementNeedReview => Icons.rate_review,
        manualDebtorReminder => Icons.notifications_active,
        friendRequest => Icons.person_add,
        friendAccepted => Icons.people,
        tripInvited => Icons.card_travel,
        tripJoined => Icons.group_add,
        unknown => Icons.notifications,
      };

  Color get iconColor => switch (this) {
        expenseCreated => const Color(0xFF3B82F6),
        expenseUpdated => const Color(0xFFF59E0B),
        expenseDeleted => const Color(0xFFEF4444),
        settlementPending => const Color(0xFF8B5CF6),
        settlementVerified => const Color(0xFF10B981),
        settlementRejected => const Color(0xFFEF4444),
        settlementNeedReview => const Color(0xFFF97316),
        manualDebtorReminder => const Color(0xFF0EA5E9),
        friendRequest => const Color(0xFF06B6D4),
        friendAccepted => const Color(0xFF10B981),
        tripInvited => const Color(0xFF3B82F6),
        tripJoined => const Color(0xFF10B981),
        unknown => const Color(0xFF6B7280),
      };
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  final String? actorNickname;
  final String? actorAvatarUrl;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.metadata,
    this.actorNickname,
    this.actorAvatarUrl,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: NotificationType.fromString(json['type'] as String? ?? ''),
      title: json['title'] as String,
      body: json['body'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
      actorNickname: actor?['nickname'] as String?,
      actorAvatarUrl: actor?['avatar_url'] as String?,
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      body: body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      metadata: metadata,
      actorNickname: actorNickname,
      actorAvatarUrl: actorAvatarUrl,
    );
  }
}
