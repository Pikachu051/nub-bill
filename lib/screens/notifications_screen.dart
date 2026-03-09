import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nubbill/models/notification_model.dart';
import 'package:nubbill/providers/notification_provider.dart';
import 'package:nubbill/shared/app_icons.dart';
import 'package:nubbill/widgets/notification_tile.dart';

/// Full notifications feed with pagination, pull-to-refresh and mark-all-read.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationProvider.notifier).loadMore();
    }
  }

  String _routeForNotification(AppNotification notification) {
    final tripId = notification.metadata?['trip_id'] as String?;
    final expenseId = notification.metadata?['expense_id'] as String?;
    return switch (notification.type) {
      NotificationType.expenseCreated ||
      NotificationType.expenseUpdated ||
      NotificationType.expenseDeleted ||
      NotificationType.settlementPending ||
      NotificationType.settlementVerified ||
      NotificationType.settlementRejected ||
      NotificationType.settlementNeedReview =>
        expenseId != null ? '/expenses/$expenseId' : '/home',
      NotificationType.friendRequest || NotificationType.friendAccepted => '/friends',
      NotificationType.tripInvited || NotificationType.tripJoined =>
        tripId != null ? '/trips/$tripId' : '/home',
      NotificationType.manualDebtorReminder =>
        tripId != null ? '/trips/$tripId' : '/friends',
      NotificationType.unknown => '/notifications',
    };
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationProvider);
    final notificationNotifier = ref.read(notificationProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: const Text(
          'แจ้งเตือน',
          style: TextStyle(
            fontFamily: 'LINESeedSansTH',
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (notificationState.unreadCount > 0)
            TextButton(
              onPressed: notificationNotifier.markAllRead,
              child: const Text(
                'อ่านทั้งหมด',
                style: TextStyle(
                  fontFamily: 'LINESeedSansTH',
                  color: Color(0xFF81CEF2),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: notificationNotifier.refresh,
        color: const Color(0xFF81CEF2),
        child: _buildBody(notificationState, notificationNotifier),
      ),
    );
  }

  Widget _buildBody(
    NotificationState notificationState,
    NotificationNotifier notificationNotifier,
  ) {
    if (notificationState.isLoading && notificationState.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF81CEF2)));
    }

    if (notificationState.error != null && notificationState.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              notificationState.error!,
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: notificationNotifier.refresh,
              child: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      );
    }

    if (notificationState.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.notifications, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'ไม่มีการแจ้งเตือน',
              style: TextStyle(
                fontFamily: 'LINESeedSansTH',
                fontSize: 18,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'เมื่อมีกิจกรรมใหม่ คุณจะเห็นที่นี่',
              style: TextStyle(
                fontFamily: 'LINESeedSansTH',
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    final groupedByDate = _groupNotificationsByDate(notificationState.notifications);

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 8),
        for (final dateGroup in groupedByDate) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              _formatDateHeader(dateGroup.date),
              style: const TextStyle(
                fontFamily: 'LINESeedSansTH',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xB2141416),
              ),
            ),
          ),
          for (var index = 0; index < dateGroup.notifications.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: NotificationTile(
                notification: dateGroup.notifications[index],
                onTap: () {
                  final selectedNotification = dateGroup.notifications[index];
                  if (!selectedNotification.isRead) {
                    notificationNotifier.markRead(selectedNotification.id);
                  }
                  context.go(_routeForNotification(selectedNotification));
                },
                onDismiss: () {
                  notificationNotifier.deleteNotification(
                    dateGroup.notifications[index].id,
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
        if (notificationState.hasMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF81CEF2),
                strokeWidth: 2,
              ),
            ),
          ),
      ],
    );
  }

  List<_NotificationDateGroup> _groupNotificationsByDate(
    List<AppNotification> notifications,
  ) {
    final grouped = <DateTime, List<AppNotification>>{};

    for (final notification in notifications) {
      final date = DateTime(
        notification.createdAt.year,
        notification.createdAt.month,
        notification.createdAt.day,
      );
      grouped.putIfAbsent(date, () => <AppNotification>[]).add(notification);
    }

    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return sortedDates
        .map((date) => _NotificationDateGroup(date, grouped[date]!))
        .toList();
  }

  String _formatDateHeader(DateTime date) {
    const monthNames = <String>[
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];

    final buddhistYear = date.year + 543;
    return '${date.day} ${monthNames[date.month - 1]} $buddhistYear';
  }
}

class _NotificationDateGroup {
  final DateTime date;
  final List<AppNotification> notifications;

  const _NotificationDateGroup(this.date, this.notifications);
}
