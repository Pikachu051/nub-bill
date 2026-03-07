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

  String _getRouteFor(AppNotification n) {
    final tripId = n.metadata?['trip_id'] as String?;
    final expenseId = n.metadata?['expense_id'] as String?;
    return switch (n.type) {
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
      NotificationType.unknown => '/notifications',
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);
    final notifier = ref.read(notificationProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.grey[50],
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
          if (state.unreadCount > 0)
            TextButton(
              onPressed: notifier.markAllRead,
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
        onRefresh: notifier.refresh,
        color: const Color(0xFF81CEF2),
        child: _buildBody(state, notifier),
      ),
    );
  }

  Widget _buildBody(NotificationState state, NotificationNotifier notifier) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF81CEF2)));
    }

    if (state.error != null && state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              state.error!,
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: notifier.refresh,
              child: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      );
    }

    if (state.notifications.isEmpty) {
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

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: state.notifications.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= state.notifications.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF81CEF2),
                strokeWidth: 2,
              ),
            ),
          );
        }

        final n = state.notifications[index];
        return NotificationTile(
          notification: n,
          onTap: () {
            if (!n.isRead) notifier.markRead(n.id);
            context.go(_getRouteFor(n));
          },
          onDismiss: () {
            // Optimistically remove; backend delete is fire-and-forget
            notifier.markRead(n.id);
          },
        );
      },
    );
  }
}
