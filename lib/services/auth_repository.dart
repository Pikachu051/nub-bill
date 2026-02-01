import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/config/supabase_config.dart';

// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(SupabaseConfig.client);
});

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signInWithEmail(String email) async {
    await _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: 'io.supabase.flutter://login-callback/',
    );
  }

  Future<AuthResponse> verifyOtp(String email, String token) async {
    return await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> updateNickname(String nickname) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Update auth metadata
    await _client.auth.updateUser(UserAttributes(data: {'nickname': nickname}));

    // Update profiles table if it exists (assuming trigger or manual update)
    // The prototype API calls PATCH /api/profile.
    // If backend handles it, we should call backend API?
    // Or just update Supabase directly?
    // Since we are frontend only for now and using Supabase directly in other places?
    // "API Call: PATCH /api/profile" in README suggests a backend endpoint.
    // The backend is "nub-bill-backend", using Elysia.
    // If we use Supabase Flutter SDK, we can update directly if RLS allows.
    // For now I'll use Supabase SDK update which updates `auth.users` metadata
    // AND `public.profiles` if there is a trigger.

    // Also explicitly update public.profiles if needed
    await _client
        .from('profiles')
        .update({'nickname': nickname})
        .eq('id', user.id);
  }
}
