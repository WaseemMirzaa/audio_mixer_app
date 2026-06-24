import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/screens/auth/forgot_password_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/signup_screen.dart';
import '../../presentation/screens/dev/demo_selector_screen.dart';
import '../../presentation/screens/dev/dev_tools_screen.dart';
import '../../presentation/screens/history/history_screen.dart';
import '../../presentation/screens/history/session_detail_screen.dart';
import '../../presentation/screens/home/home_dashboard_screen.dart';
import '../../presentation/screens/misc/about_app_screen.dart';
import '../../presentation/screens/misc/backup_screen.dart';
import '../../presentation/screens/misc/delete_account_screen.dart';
import '../../presentation/screens/misc/error_screen.dart';
import '../../presentation/screens/misc/permission_screen.dart';
import '../../presentation/screens/misc/privacy_policy_screen.dart';
import '../../presentation/screens/misc/subscription_expired_screen.dart';
import '../../presentation/screens/misc/terms_of_service_screen.dart';
import '../../presentation/screens/mixer/mixer_background_upload_screen.dart';
import '../../presentation/screens/mixer/mixer_transport_screen.dart';
import '../../presentation/screens/onboarding/get_started_screen.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/profile/account_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/shell/app_shell.dart';
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/subscription/paywall_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => SplashScreen(
          debugPreview: state.uri.queryParameters['debug'] == '1',
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingScreen(
          replay: state.uri.queryParameters['replay'] == '1',
        ),
      ),
      GoRoute(
        path: '/get-started',
        builder: (context, state) => const GetStartedScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(shell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/picker',
        // Guests CAN explore the session-creation flow; only saving/creating a
        // session is gated (handled in the player with a sign-in dialog).
        // A fade keeps the shared player backdrop steady, so the transition
        // into/out of the player reads as one smooth cross-fade.
        pageBuilder: (context, state) =>
            _fadePage(state, const MixerBackgroundUploadScreen()),
      ),
      GoRoute(
        path: '/mixer',
        pageBuilder: (context, state) =>
            _fadePage(state, const MixerTransportScreen()),
      ),
      GoRoute(
        path: '/session/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SessionDetailScreen(sessionId: id);
        },
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutAppScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) => const TermsOfServiceScreen(),
      ),
      GoRoute(
        path: '/backup',
        builder: (context, state) => const BackupScreen(),
      ),
      GoRoute(
        path: '/delete-account',
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: '/permission',
        builder: (context, state) => const PermissionScreen(),
      ),
      GoRoute(
        path: '/subscription-expired',
        builder: (context, state) => const SubscriptionExpiredScreen(),
      ),
      GoRoute(
        path: '/error',
        builder: (context, state) {
          final msg = state.uri.queryParameters['msg'];
          return ErrorScreen(message: msg);
        },
      ),
      GoRoute(
        path: '/demo-selector',
        builder: (context, state) => const DemoSelectorScreen(),
      ),
      GoRoute(
        path: '/dev-tools',
        builder: (context, state) => const DevToolsScreen(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

/// A fast cross-fade page transition. Used for the core New Session ⇄ Player
/// flow where both screens share the same full-bleed backdrop — a plain fade
/// avoids the default zoom/slide compositing two heavy backgrounds at once,
/// which is what made that transition feel laggy.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}
