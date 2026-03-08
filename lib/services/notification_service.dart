import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import 'package:nubbill/config/api_config.dart';
import 'package:nubbill/config/router.dart';
import 'package:nubbill/config/supabase_config.dart';

// Top-level handler required by firebase_messaging for background isolate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages on Android are shown automatically by FCM.
  // No action needed here; taps are handled via onMessageOpenedApp / getInitialMessage.
}

const _channelId = 'nub_bill_notifications';
const _channelName = 'Nub-Bill แจ้งเตือน';

final _localNotifications = FlutterLocalNotificationsPlugin();

class NotificationService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request OS permission (Android 13+ / iOS)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Initialise flutter_local_notifications (used for foreground messages)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) _navigateFromPayload(details.payload!);
      },
    );

    // Create the Android notification channel
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'การแจ้งเตือนจาก Nub-Bill',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Show a local notification for foreground FCM messages
    FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n == null) return;
      _localNotifications.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: jsonEncode(message.data),
      );
    });

    // App opened from background by tapping a notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _navigateFromData(message.data);
    });

    // App launched from terminated state by tapping a notification
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateFromData(initial.data);
      });
    }

    // Register this device's push token with the backend
    await syncPushToken();
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
  }

  // ---------------------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------------------

  static String _getRouteForData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final tripId = data['trip_id'] as String?;
    final expenseId = data['expense_id'] as String?;

    return switch (type) {
      'expense_created' ||
      'expense_updated' ||
      'expense_deleted' ||
      'settlement_pending' ||
      'settlement_verified' ||
      'settlement_rejected' ||
      'settlement_need_review' =>
        expenseId != null ? '/expenses/$expenseId' : '/home',
      'friend_request' || 'friend_accepted' => '/friends',
      'trip_invited' || 'trip_joined' =>
        tripId != null ? '/trips/$tripId' : '/home',
      'manual_debtor_reminder' =>
        tripId != null ? '/trips/$tripId' : '/friends',
      _ => '/notifications',
    };
  }

  static void _navigateFromData(Map<String, dynamic> data) {
    final route = _getRouteForData(data);
    final context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      context.go(route);
    }
  }

  static void _navigateFromPayload(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _navigateFromData(data);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Token registration
  // ---------------------------------------------------------------------------

  static Future<void> syncPushToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _saveToken(token);
  }

  static Future<void> _saveToken(String token) async {
    try {
      // Push token mapping is user-scoped; skip until user session exists.
      if (SupabaseConfig.client.auth.currentSession == null) {
        return;
      }

      final platform = Platform.isIOS ? 'ios' : 'android';
      final client = ApiClient();
      final response = await client.post(
        '/notifications/push-token',
        body: {'token': token, 'platform': platform},
      );

      if (!response.isSuccess) {
        debugPrint(
          'Push token registration failed: status=${response.statusCode}, error=${response.error}',
        );
      }
    } catch (e) {
      // Token registration is best-effort; failures are non-fatal.
      debugPrint('Push token registration exception: $e');
    }
  }
}
