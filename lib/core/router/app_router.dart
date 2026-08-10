import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_gate.dart';
import '../../features/auth/presentation/email_verification_flow_observer.dart';
import '../../features/auth/presentation/otp_flow_observer.dart';
import '../../features/auth/presentation/providers/email_verification_flow_provider.dart';
import '../../features/auth/presentation/providers/otp_flow_provider.dart';
import '../../features/auth/presentation/screens/email_verification_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_entry_gate.dart';
import '../../features/poster/presentation/screens/poster_detail_screen.dart';
import 'app_routes.dart';
import 'route_state_guard.dart';

/// The authenticated destination, kept as a top-level function so
/// [AuthGate]'s `builder` stays const-constructible. `AuthGate` itself is
/// unchanged: this round keeps auth as a widget wrapping the first route and
/// does **not** move it to a route-level `redirect` (ADR-0018 D4).
Widget buildHomeScreen(BuildContext context) => const HomeScreen();

/// The app's route table.
///
/// Exposed as a plain list — not only through [routerProvider] — so tests can
/// stand up a `GoRouter` over the *real* table at any initial location.
/// That matters: every widget test in this repo used to pump
/// `MaterialApp(home: X)`, which stays green even if the whole table is wrong
/// (ADR-0018 D9).
final List<RouteBase> appRoutes = <RouteBase>[
  GoRoute(
    path: AppRoutes.onboardingPath,
    name: AppRoutes.onboardingName,
    // The gate, not the screen. Why this is a widget and what it costs to
    // change that is documented once, on `OnboardingEntryGate` itself.
    builder: (BuildContext context, GoRouterState state) =>
        const OnboardingEntryGate(),
  ),
  GoRoute(
    path: AppRoutes.homePath,
    name: AppRoutes.homeName,
    builder: (BuildContext context, GoRouterState state) =>
        const AuthGate(builder: buildHomeScreen),
  ),
  GoRoute(
    path: AppRoutes.registerPath,
    name: AppRoutes.registerName,
    builder: (BuildContext context, GoRouterState state) =>
        const RegisterScreen(),
  ),
  GoRoute(
    path: AppRoutes.otpPath,
    name: AppRoutes.otpName,
    // Carries no arguments at all (ADR-0018 Amendment 2 A2-D2): the flow's
    // state lives in `otpFlowProvider`, so a `GoRouter.refresh()` while the
    // user is standing here rebuilds this route with the state still intact
    // instead of dropping it. There is no `redirect` for the same reason
    // there is no cast — nothing about this route depends on `extra` any
    // more, and `redirect` would not run for a pushed match anyway.
    builder: (BuildContext context, GoRouterState state) => Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? _) =>
          // `read`, not `watch` — see `requireRouteState`: subscribing would
          // rebuild this route when the flow is cleared on the way out and
          // bounce a user who tapped back to home instead.
          requireRouteState<OtpFlowState>(
            context,
            ref.read(otpFlowProvider),
            builder: (OtpFlowState flow) =>
                OtpVerificationScreen(phoneNumber: flow.phoneNumber),
          ),
    ),
  ),
  GoRoute(
    path: AppRoutes.emailVerificationPath,
    name: AppRoutes.emailVerificationName,
    // Same shape as `/otp` above (ADR-0021 D2 applying ADR-0018 Amendment 2
    // A2-D2): carries no arguments, reads its state from
    // `emailVerificationFlowProvider` via `requireRouteState`.
    builder: (BuildContext context, GoRouterState state) => Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? _) =>
          requireRouteState<EmailVerificationFlowState>(
            context,
            ref.read(emailVerificationFlowProvider),
            builder: (EmailVerificationFlowState flow) =>
                EmailVerificationScreen(
                  email: flow.email,
                  justSentEmail: flow.justSentEmail,
                ),
          ),
    ),
  ),
  GoRoute(
    path: AppRoutes.posterDetailPath,
    name: AppRoutes.posterDetailName,
    builder: (BuildContext context, GoRouterState state) => PosterDetailScreen(
      posterId: state.pathParameters[AppRoutes.posterIdParam]!,
    ),
  ),
];

/// The single `GoRouter` the app runs on, wired into `MaterialApp.router` in
/// `main.dart`. A `Provider` rather than a bare global so it can be
/// overridden in a `ProviderScope` like every other dependency in this repo.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.onboardingPath,
    routes: appRoutes,
    // Ends the phone-verification flow when the user leaves `/otp` for real.
    // An observer rather than a route or widget callback because those also
    // fire on a `refresh()` that never took the user anywhere — the reasoning
    // and the evidence are in `OtpFlowObserver`.
    observers: <NavigatorObserver>[
      OtpFlowObserver(ref),
      EmailVerificationFlowObserver(ref),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
