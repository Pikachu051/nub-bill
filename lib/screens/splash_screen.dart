import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nubbill/services/auth_repository.dart';
import 'package:nubbill/services/onboarding_state.dart';
import 'package:nubbill/config/theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Artificial delay for splash animation (1.5 - 2 seconds as per prototype)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    final session = ref.read(authRepositoryProvider).currentSession;

    if (session != null) {
      await OnboardingState.markLoggedInOnce();
      if (!mounted) return;
      context.go('/home');
    } else {
      final hasLoggedInOnce = await OnboardingState.hasLoggedInOnce();
      if (!mounted) return;
      context.go(hasLoggedInOnce ? '/welcome' : '/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Nub Bill Logo
            Image.asset(
              'assets/images/nub_bill_logo.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
