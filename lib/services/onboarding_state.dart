import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has ever completed a successful login.
///
/// Once true, onboarding should never be shown again.
class OnboardingState {
  static const String _kHasLoggedInOnceKey = 'has_logged_in_once';
  static bool? _hasLoggedInOnceCache;

  static Future<bool> hasLoggedInOnce() async {
    if (_hasLoggedInOnceCache != null) {
      return _hasLoggedInOnceCache!;
    }

    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_kHasLoggedInOnceKey) ?? false;
    _hasLoggedInOnceCache = value;
    return value;
  }

  static Future<void> markLoggedInOnce() async {
    if (_hasLoggedInOnceCache == true) {
      return;
    }

    _hasLoggedInOnceCache = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasLoggedInOnceKey, true);
  }
}
