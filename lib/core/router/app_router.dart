import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_gate.dart';
import '../../features/auth/presentation/otp_route_args.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_page_view_screen.dart';
import '../../features/poster/presentation/screens/poster_detail_screen.dart';
import 'app_routes.dart';

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
    builder: (BuildContext context, GoRouterState state) =>
        const OnboardingPageViewScreen(),
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
    // `extra` does not survive a process restore, and nothing stops a future
    // deep link from naming this path. Both arrive here with no arguments,
    // and the screen cannot exist without them — so send those cases home
    // instead of letting the cast below blow up on the user.
    redirect: (BuildContext context, GoRouterState state) =>
        state.extra is OtpRouteArgs ? null : AppRoutes.homePath,
    builder: (BuildContext context, GoRouterState state) {
      // The single place `GoRouterState.extra` is cast anywhere in the app
      // (ADR-0018 D6). The `redirect` above is what makes it safe; if the
      // two ever get out of step this is where it shows.
      final OtpRouteArgs args = state.extra! as OtpRouteArgs;
      return OtpVerificationScreen(
        phoneNumber: args.phoneNumber,
        verificationId: args.verificationId,
        resendToken: args.resendToken,
      );
    },
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
  );
  ref.onDispose(router.dispose);
  return router;
});
