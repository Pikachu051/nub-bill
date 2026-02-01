/// Supabase configuration for Nub-Bill
///
/// This file initializes the Supabase client for authentication and database access.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase project configuration
class SupabaseConfig {
  // Supabase project URL
  static const String url = 'https://xyutxookhelfshzjduuf.supabase.co';

  // Supabase anonymous key (safe to expose in client)
  static const String anonKey =
      'sb_publishable_kkUfZhEd0UKICqGl3skU-g_vnvfbNOu';

  /// Initialize Supabase - call this in main() before runApp()
  static Future<void> initialize() async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  /// Get the Supabase client instance
  static SupabaseClient get client => Supabase.instance.client;

  /// Get the current user (null if not logged in)
  static User? get currentUser => client.auth.currentUser;

  /// Check if user is logged in
  static bool get isLoggedIn => currentUser != null;
}
