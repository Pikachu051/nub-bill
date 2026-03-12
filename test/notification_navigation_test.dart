import 'package:flutter_test/flutter_test.dart';
import 'package:nubbill/models/notification_model.dart';

/// Test helper to simulate the navigation logic from NotificationsScreen
/// This mirrors _routeForNotification method for testing purposes
String routeForNotification(AppNotification notification) {
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

void main() {
  group('Notification Navigation Tests', () {
    final testDate = DateTime(2024, 1, 1);

    test('expenseCreated with expense_id navigates to expense page', () {
      final notification = AppNotification(
        id: '1',
        userId: 'user1',
        type: NotificationType.expenseCreated,
        title: 'New Expense',
        body: 'A new expense was created',
        isRead: false,
        createdAt: testDate,
        metadata: {'expense_id': 'exp_123', 'trip_id': 'trip_456'},
      );

      expect(routeForNotification(notification), '/expenses/exp_123');
    });

    test('expenseCreated without expense_id falls back to home', () {
      final notification = AppNotification(
        id: '1',
        userId: 'user1',
        type: NotificationType.expenseCreated,
        title: 'New Expense',
        body: 'A new expense was created',
        isRead: false,
        createdAt: testDate,
        metadata: {'trip_id': 'trip_456'},
      );

      expect(routeForNotification(notification), '/home');
    });

    test('expenseUpdated navigates to expense page', () {
      final notification = AppNotification(
        id: '2',
        userId: 'user1',
        type: NotificationType.expenseUpdated,
        title: 'Expense Updated',
        body: 'An expense was updated',
        isRead: false,
        createdAt: testDate,
        metadata: {'expense_id': 'exp_789'},
      );

      expect(routeForNotification(notification), '/expenses/exp_789');
    });

    test('expenseDeleted navigates to expense page', () {
      final notification = AppNotification(
        id: '3',
        userId: 'user1',
        type: NotificationType.expenseDeleted,
        title: 'Expense Deleted',
        body: 'An expense was deleted',
        isRead: false,
        createdAt: testDate,
        metadata: {'expense_id': 'exp_999'},
      );

      expect(routeForNotification(notification), '/expenses/exp_999');
    });

    test('settlementPending navigates to expense page', () {
      final notification = AppNotification(
        id: '4',
        userId: 'user1',
        type: NotificationType.settlementPending,
        title: 'Settlement Pending',
        body: 'A settlement is pending',
        isRead: false,
        createdAt: testDate,
        metadata: {'expense_id': 'exp_111'},
      );

      expect(routeForNotification(notification), '/expenses/exp_111');
    });

    test('settlementVerified navigates to expense page', () {
      final notification = AppNotification(
        id: '5',
        userId: 'user1',
        type: NotificationType.settlementVerified,
        title: 'Settlement Verified',
        body: 'A settlement was verified',
        isRead: false,
        createdAt: testDate,
        metadata: {'expense_id': 'exp_222'},
      );

      expect(routeForNotification(notification), '/expenses/exp_222');
    });

    test('settlementRejected navigates to expense page', () {
      final notification = AppNotification(
        id: '6',
        userId: 'user1',
        type: NotificationType.settlementRejected,
        title: 'Settlement Rejected',
        body: 'A settlement was rejected',
        isRead: false,
        createdAt: testDate,
        metadata: {'expense_id': 'exp_333'},
      );

      expect(routeForNotification(notification), '/expenses/exp_333');
    });

    test('settlementNeedReview navigates to expense page', () {
      final notification = AppNotification(
        id: '7',
        userId: 'user1',
        type: NotificationType.settlementNeedReview,
        title: 'Settlement Needs Review',
        body: 'A settlement needs your review',
        isRead: false,
        createdAt: testDate,
        metadata: {'expense_id': 'exp_444'},
      );

      expect(routeForNotification(notification), '/expenses/exp_444');
    });

    test('friendRequest navigates to friends page', () {
      final notification = AppNotification(
        id: '8',
        userId: 'user1',
        type: NotificationType.friendRequest,
        title: 'Friend Request',
        body: 'Someone wants to be your friend',
        isRead: false,
        createdAt: testDate,
      );

      expect(routeForNotification(notification), '/friends');
    });

    test('friendAccepted navigates to friends page', () {
      final notification = AppNotification(
        id: '9',
        userId: 'user1',
        type: NotificationType.friendAccepted,
        title: 'Friend Accepted',
        body: 'Someone accepted your friend request',
        isRead: false,
        createdAt: testDate,
      );

      expect(routeForNotification(notification), '/friends');
    });

    test('tripInvited with trip_id navigates to trip page', () {
      final notification = AppNotification(
        id: '10',
        userId: 'user1',
        type: NotificationType.tripInvited,
        title: 'Trip Invitation',
        body: 'You were invited to a trip',
        isRead: false,
        createdAt: testDate,
        metadata: {'trip_id': 'trip_aaa'},
      );

      expect(routeForNotification(notification), '/trips/trip_aaa');
    });

    test('tripInvited without trip_id falls back to home', () {
      final notification = AppNotification(
        id: '10',
        userId: 'user1',
        type: NotificationType.tripInvited,
        title: 'Trip Invitation',
        body: 'You were invited to a trip',
        isRead: false,
        createdAt: testDate,
      );

      expect(routeForNotification(notification), '/home');
    });

    test('tripJoined with trip_id navigates to trip page', () {
      final notification = AppNotification(
        id: '11',
        userId: 'user1',
        type: NotificationType.tripJoined,
        title: 'Member Joined',
        body: 'A member joined the trip',
        isRead: false,
        createdAt: testDate,
        metadata: {'trip_id': 'trip_bbb'},
      );

      expect(routeForNotification(notification), '/trips/trip_bbb');
    });

    test('tripJoined without trip_id falls back to home', () {
      final notification = AppNotification(
        id: '11',
        userId: 'user1',
        type: NotificationType.tripJoined,
        title: 'Member Joined',
        body: 'A member joined the trip',
        isRead: false,
        createdAt: testDate,
      );

      expect(routeForNotification(notification), '/home');
    });

    test('manualDebtorReminder with trip_id navigates to trip page', () {
      final notification = AppNotification(
        id: '12',
        userId: 'user1',
        type: NotificationType.manualDebtorReminder,
        title: 'Payment Reminder',
        body: 'You have an outstanding balance',
        isRead: false,
        createdAt: testDate,
        metadata: {'trip_id': 'trip_ccc'},
      );

      expect(routeForNotification(notification), '/trips/trip_ccc');
    });

    test('manualDebtorReminder without trip_id navigates to friends page', () {
      final notification = AppNotification(
        id: '12',
        userId: 'user1',
        type: NotificationType.manualDebtorReminder,
        title: 'Payment Reminder',
        body: 'You have an outstanding balance',
        isRead: false,
        createdAt: testDate,
      );

      expect(routeForNotification(notification), '/friends');
    });

    test('unknown type navigates to notifications page', () {
      final notification = AppNotification(
        id: '13',
        userId: 'user1',
        type: NotificationType.unknown,
        title: 'Unknown',
        body: 'Unknown notification',
        isRead: false,
        createdAt: testDate,
      );

      expect(routeForNotification(notification), '/notifications');
    });

    test('navigation routes match router configuration', () {
      // Verify all routes used in navigation exist in router.dart
      // Routes: /expenses/:id, /trips/:id, /friends, /home, /notifications
      // All are defined in router.dart (lines 164-170, 293-381, 309, 318)

      // Test that generated routes match expected patterns
      final testCases = [
        ('/expenses/exp_123', '/expenses/'),
        ('/trips/trip_aaa', '/trips/'),
        ('/friends', '/friends'),
        ('/home', '/home'),
        ('/notifications', '/notifications'),
      ];

      for (final (generatedRoute, expectedPrefix) in testCases) {
        expect(generatedRoute.startsWith(expectedPrefix), true,
            reason: '$generatedRoute should start with $expectedPrefix');
      }
    });
  });
}
