import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/services/friend_service.dart';
import 'package:nubbill/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for the deep link service
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService(ref);
});

/// Service to handle incoming deep links
class DeepLinkService {
  final Ref _ref;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  BuildContext? _context;

  DeepLinkService(this._ref);

  /// Initialize the deep link listener
  void initialize(BuildContext context) {
    _context = context;

    // Handle link that opened the app (cold start)
    _handleInitialLink();

    // Handle links while app is running (warm start)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (err) {
        debugPrint('Deep link error: $err');
      },
    );

    // Listen for Supabase auth events (password recovery)
    _authSubscription = SupabaseConfig.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        // User clicked the password reset link - navigate to reset page
        if (_context != null && _context!.mounted) {
          GoRouter.of(_context!).go('/reset-password');
        }
      }
    });
  }

  /// Handle the initial link that opened the app
  Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleDeepLink(uri);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }
  }

  /// Handle incoming deep link
  void _handleDeepLink(Uri uri) {
    debugPrint('Received deep link: $uri');

    if (uri.scheme == 'nubbill') {
      final pathSegments = uri.pathSegments;

      // nubbill://friend/add/{userId}
      if (pathSegments.length >= 3 &&
          pathSegments[0] == 'friend' &&
          pathSegments[1] == 'add') {
        final userId = pathSegments[2];
        _handleAddFriend(userId);
        return;
      }

      // nubbill://reset-password (handled by Supabase auth listener)
      if (pathSegments.isNotEmpty && pathSegments[0] == 'reset-password') {
        // Supabase handles the token extraction; auth listener navigates
        return;
      }
    }
  }

  /// Handle add friend deep link
  Future<void> _handleAddFriend(String userId) async {
    if (_context == null) return;

    // Validate UUID format
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    if (!uuidRegex.hasMatch(userId)) {
      _showMessage('ลิงก์ไม่ถูกต้อง');
      return;
    }

    try {
      await _ref.read(friendServiceProvider).sendRequestById(userId);
      _ref.invalidate(pendingRequestsProvider);
      _showMessage('ส่งคำขอเป็นเพื่อนแล้ว!');
    } catch (e) {
      _showMessage('$e');
    }
  }

  /// Show a snackbar message
  void _showMessage(String message) {
    if (_context != null && _context!.mounted) {
      ScaffoldMessenger.of(
        _context!,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Dispose the subscription
  void dispose() {
    _linkSubscription?.cancel();
    _authSubscription?.cancel();
  }
}
