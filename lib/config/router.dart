import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nubbill/services/auth_repository.dart';
import 'package:nubbill/screens/login_page.dart';
import 'package:nubbill/screens/otp_screen.dart';
import 'package:nubbill/screens/onboarding_screen.dart';
import 'package:nubbill/screens/nickname_screen.dart';
import 'package:nubbill/screens/splash_screen.dart';
import 'package:nubbill/screens/home_page.dart';
import 'package:nubbill/screens/scaffold_with_navbar.dart';
import 'package:nubbill/screens/create_group_screen.dart';
import 'package:nubbill/screens/bill_details_page.dart';
import 'package:nubbill/screens/payment_screen.dart';
import 'package:nubbill/screens/manage_balance_page.dart';
import 'package:nubbill/screens/group_detail_page.dart';
import 'package:nubbill/screens/friends_screen.dart';
import 'package:nubbill/screens/profile_screen.dart';
import 'package:nubbill/screens/payment_methods_screen.dart';
import 'package:nubbill/screens/add_payment_method_screen.dart';
import 'package:nubbill/screens/authentication_page.dart';
import 'package:nubbill/screens/register_page.dart';
import 'package:nubbill/screens/notifications_screen.dart';
import 'package:nubbill/screens/forgot_password_page.dart';
import 'package:nubbill/screens/reset_password_page.dart';
import 'package:nubbill/screens/add_expense_screen.dart';
import 'package:nubbill/models/trip_member_model.dart';
import 'package:nubbill/models/trip_model.dart';
import 'package:nubbill/services/profile_service.dart';
import 'package:nubbill/services/onboarding_state.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  CreateGroupScreen buildCreateGroupScreen(GoRouterState state) {
    final extra = state.extra;
    Trip? trip;
    List<TripMember>? members;

    if (extra is Map<String, dynamic>) {
      final maybeTrip = extra['trip'];
      final maybeMembers = extra['members'];

      if (maybeTrip is Trip) {
        trip = maybeTrip;
      }
      if (maybeMembers is List<TripMember>) {
        members = maybeMembers;
      } else if (maybeMembers is List) {
        members = maybeMembers
            .map((e) => e is TripMember
                ? e
                : TripMember.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    return CreateGroupScreen(initialTrip: trip, initialMembers: members);
  }

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(authRepository.authStateChanges),
    redirect: (context, state) async {
      final session = authRepository.currentSession;
      final isLoggedIn = session != null;
      final isLoggingIn =
          state.uri.path == '/login' ||
          state.uri.path == '/register' ||
          state.uri.path == '/welcome' ||
          state.uri.path == '/otp' ||
          state.uri.path == '/forgot-password' ||
          state.uri.path == '/reset-password';
      final isSplash = state.uri.path == '/';
      final isNickname = state.uri.path == '/nickname';

      // We handle the initial splash logic in SplashScreen
      if (isSplash) return null;

      final isOnboarding = state.uri.path == '/onboarding';
      final hasLoggedInOnce = await OnboardingState.hasLoggedInOnce();

      if (!isLoggedIn) {
        if (isOnboarding && hasLoggedInOnce) {
          return '/welcome';
        }

        if (isLoggingIn || isOnboarding) return null;

        return '/welcome';
      }

      if (isLoggedIn) {
        // Check if user has nickname
        final user = authRepository.currentUser;
        final hasNickname = user?.userMetadata?['nickname'] != null;

        if (!hasNickname) {
          if (isNickname) return null;
          return '/nickname';
        }

        // If logged in and has nickname, prevent access to login/nickname pages
        if (isLoggingIn || isNickname) {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const AuthenticationPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return OtpScreen(email: email);
        },
      ),
      GoRoute(
        path: '/nickname',
        builder: (context, state) => const NicknameScreen(),
      ),
      GoRoute(
        path: '/expenses/:id',
        builder: (context, state) {
          final expenseId = state.pathParameters['id'] ?? '';
          return BillDetailsPage(expenseId: expenseId);
        },
      ),
      GoRoute(
        path: '/add_expense',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final membersRaw = extra['members'];
          List<TripMember>? members;
          if (membersRaw is List<TripMember>) {
            members = membersRaw;
          } else if (membersRaw is List) {
            members = membersRaw
                .map((e) => e is TripMember
                    ? e
                    : TripMember.fromJson(e as Map<String, dynamic>))
                .toList();
          }
          return AddExpenseScreen(
            tripId: extra['tripId'] as String? ?? '',
            tripName: extra['tripName'] as String? ?? '',
            members: members,
            expenseId: extra['expenseId'] as String?,
            isEdit: extra['isEdit'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: '/payment',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            final splitIdsRaw = extra['expenseSplitIds'];
            List<String>? splitIds;
            if (splitIdsRaw is List<String>) {
              splitIds = splitIdsRaw;
            } else if (splitIdsRaw is List) {
              splitIds = splitIdsRaw.map((item) => item.toString()).toList();
            }

            final counterSplitIdsRaw = extra['counterExpenseSplitIds'];
            List<String>? counterSplitIds;
            if (counterSplitIdsRaw is List<String>) {
              counterSplitIds = counterSplitIdsRaw;
            } else if (counterSplitIdsRaw is List) {
              counterSplitIds = counterSplitIdsRaw.map((item) => item.toString()).toList();
            }

            return PaymentScreen(
              amount: (extra['amount'] as num?)?.toDouble() ?? 0,
              memberId: extra['memberId'] as String?,
              tripId: extra['tripId'] as String?,
              payeeName: extra['payeeName'] as String?,
              payeeAvatarUrl: extra['payeeAvatarUrl'] as String?,
              promptpayId: extra['promptpayId'] as String?,
              expenseSplitIds: splitIds,
              counterExpenseSplitIds: counterSplitIds,
            );
          }
          return const PaymentScreen();
        },
      ),
      GoRoute(
        path: '/manage-balance',
        builder: (context, state) {
          final extra = state.extra;
          String groupId = '';
          if (extra is Map<String, dynamic>) {
            groupId = extra['groupId'] as String? ?? '';
          }

          return ManageBalancePage(groupId: groupId);
        },
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordPage(),
      ),
      GoRoute(
        path: '/payment-methods',
        redirect: (context, state) => '/profile/payment-methods',
      ),
      GoRoute(
        path: '/add-payment-method',
        builder: (context, state) {
          final extra = state.extra;
          final editingMethod = extra is PaymentMethod ? extra : null;
          return AddPaymentMethodScreen(editingMethod: editingMethod);
        },
      ),

      // Bottom Nav Shell - 4 tabs matching design
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Tab 0: กลุ่ม (Groups/Home)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
                routes: [
                  GoRoute(
                    path: 'groups/create',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => buildCreateGroupScreen(state),
                  ),
                ],
              ),
            ],
          ),
          // Tab 1: เพื่อน (Friends)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/friends',
                builder: (context, state) => const FriendsScreen(),
              ),
            ],
          ),
          // Tab 2: แจ้งเตือน (Notifications)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),
          // Tab 3: โปรไฟล์ (Profile)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'payment-methods',
                    builder: (context, state) => const PaymentMethodsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Route for group details (outside of shell for full screen)
      GoRoute(
        path: '/groups/create',
        builder: (context, state) => buildCreateGroupScreen(state),
      ),
      GoRoute(
        path: '/groups/:id',
        builder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          return GroupDetailPage(groupId: groupId);
        },
      ),
      // Alias used by notification deep links
      GoRoute(
        path: '/trips/:id',
        builder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          return GroupDetailPage(groupId: groupId);
        },
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
