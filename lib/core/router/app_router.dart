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
import '../theme/app_colors.dart';
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
    // rather than letting the builder meet a half-built route.
    redirect: (BuildContext context, GoRouterState state) =>
        state.extra is OtpRouteArgs ? null : AppRoutes.homePath,
    builder: (BuildContext context, GoRouterState state) {
      // 🔴 The `redirect` above does **not** cover this, and the obvious
      // `state.extra! as OtpRouteArgs` here is a live crash. Verified on
      // go_router 17.4.0 during INF-01: calling `GoRouter.refresh()` (or
      // firing a `refreshListenable`) while standing on this route re-runs
      // *this builder* with `extra` dropped to `null`, and does **not**
      // re-run `redirect` — an already-resolved match is not re-guarded.
      // The `!` threw `Null check operator used on a null value` onto the
      // user's screen. Nothing calls `refresh()` today, but ADR-0018
      // §ต้องทำตามมา 2 moves auth to a route-level guard next round, and
      // that requires a `refreshListenable` — so this is armed, not
      // theoretical.
      //
      // This is also the only place `GoRouterState.extra` is read at all
      // besides the guard above (ADR-0018 D6) — the type promotion below
      // replaces the cast, so there is no unchecked cast left to keep in
      // step with anything.
      final Object? extra = state.extra;
      if (extra is! OtpRouteArgs) {
        // A builder cannot redirect, so leave for home on the next frame
        // and show the same spinner `AuthGate` uses while nothing is known.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go(AppRoutes.homePath);
        });
        return const Scaffold(
          backgroundColor: AppColors.surfaceDark,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        );
      }
      return OtpVerificationScreen(
        phoneNumber: extra.phoneNumber,
        verificationId: extra.verificationId,
        resendToken: extra.resendToken,
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
