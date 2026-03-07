import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/config/supabase_config.dart';
import 'package:nubbill/config/router.dart';
import 'package:nubbill/config/theme.dart';
import 'package:nubbill/services/deep_link_service.dart';
import 'package:nubbill/services/notification_service.dart';
import 'package:nubbill/widgets/retry_error_state.dart';

final supabaseBootstrapProvider = FutureProvider<void>((ref) async {
  await SupabaseConfig.initialize();
});

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  bool _deepLinkInitialized = false;
  bool _notificationInitialized = false;

  @override
  void dispose() {
    if (_deepLinkInitialized) {
      ref.read(deepLinkServiceProvider).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapAsync = ref.watch(supabaseBootstrapProvider);

    return bootstrapAsync.when(
      loading: () => MaterialApp(
        title: 'Nub-Bill',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const _BootstrapSplashScreen(),
      ),
      error: (error, _) => MaterialApp(
        title: 'Nub-Bill',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: RetryErrorState(
            error: error,
            fallbackMessage: networkTimeoutMessage,
            onRetry: () => ref.invalidate(supabaseBootstrapProvider),
          ),
        ),
      ),
      data: (_) {
        if (!_deepLinkInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _deepLinkInitialized) return;
            ref.read(deepLinkServiceProvider).initialize(context);
            setState(() => _deepLinkInitialized = true);
          });
        }

        if (!_notificationInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _notificationInitialized) return;
            NotificationService.initialize().catchError((_) {});
            setState(() => _notificationInitialized = true);
          });
        }

        final router = ref.watch(routerProvider);
        return MaterialApp.router(
          title: 'Nub-Bill',
          theme: AppTheme.lightTheme,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class _BootstrapSplashScreen extends StatelessWidget {
  const _BootstrapSplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
