import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/carechain/presentation/pages/carechain_page.dart';
import '../../features/caregiver_dashboard/presentation/pages/dashboard_page.dart';
import '../../features/consent/presentation/pages/consent_page.dart';
import '../../features/delivery_map/presentation/pages/map_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home_setup/presentation/pages/onboarding_page.dart';
import '../../features/medications/presentation/pages/medications_page.dart';
import '../../features/orders/presentation/pages/order_detail_page.dart';
import '../../features/profile/presentation/pages/credits_page.dart';
import '../../features/wearable/presentation/pages/wearable_page.dart';
import '../../features/wellbeing360/presentation/pages/wellbeing360_page.dart';
import '../di/service_locator.dart';
import '../session/auth_session.dart';
import 'app_routes.dart';

/// Central router. Guards by [AuthSession]: unauthenticated users go to /login;
/// authenticated users must pass the LGPD consent gate (RN-001) before reaching
/// data surfaces; then they are routed by role (patient → voice, others →
/// dashboard). Feature routes are added per phase.
class AppRouter {
  static final AuthSession _session = sl<AuthSession>();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: _session,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isAuthRoute =
          loc == AppRoutes.login || loc == AppRoutes.signup;

      String? decide() {
        if (!_session.isAuthenticated) {
          return isAuthRoute ? null : AppRoutes.login;
        }

        // Authenticated but consent not accepted → gate (RN-001).
        if (!_session.consentAccepted && loc != AppRoutes.consent) {
          return AppRoutes.consent;
        }

        // Already authenticated and consented: bounce away from auth/consent.
        if (isAuthRoute ||
            (loc == AppRoutes.consent && _session.consentAccepted)) {
          return homeForRole();
        }

        return null;
      }

      final target = decide();
      debugPrint(
        '[AURA-ROUTER] redirect from="$loc" '
        'auth=${_session.isAuthenticated} role=${_session.role} '
        'consent=${_session.consentAccepted} homeId=${_session.homeId} '
        '=> ${target ?? "(stay)"}',
      );
      return target;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: AppRoutes.consent,
        name: 'consent',
        builder: (context, state) => const ConsentPage(),
      ),
      GoRoute(
        path: AppRoutes.voice,
        name: 'voice',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: AppRoutes.wellbeing,
        name: 'wellbeing',
        builder: (context, state) => const Wellbeing360Page(),
      ),
      GoRoute(
        path: AppRoutes.careChain,
        name: 'carechain',
        builder: (context, state) => const CareChainPage(),
      ),
      GoRoute(
        path: '${AppRoutes.orders}/:id',
        name: 'orderDetail',
        builder: (context, state) =>
            OrderDetailPage(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/map/:orderId',
        name: 'map',
        builder: (context, state) =>
            MapPage(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: AppRoutes.wearable,
        name: 'wearable',
        builder: (context, state) => const WearablePage(),
      ),
      GoRoute(
        path: AppRoutes.medications,
        name: 'medications',
        builder: (context, state) => const MedicationsPage(),
      ),
      GoRoute(
        path: AppRoutes.credits,
        name: 'credits',
        builder: (context, state) => const CreditsPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Erro: ${state.error}')),
    ),
  );

  /// Landing route based on the authenticated role. Used both by the redirect
  /// guard and by post-auth/consent listeners so the patient (voice-first) and
  /// caregiver (dashboard/onboarding) surfaces are never confused.
  static String homeForRole() {
    final role = _session.role;
    final String target;
    if (role != null && role.isPatient) {
      target = AppRoutes.voice;
    } else {
      // Caregiver/professional land on the dashboard (added in Fase 2). Until
      // then, ensure a home exists or send to onboarding.
      target =
          _session.homeId == null ? AppRoutes.onboarding : AppRoutes.dashboard;
    }
    debugPrint('[AURA-ROUTER] homeForRole role=$role => $target');
    return target;
  }
}
