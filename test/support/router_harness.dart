import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:posternung/core/router/app_router.dart';
import 'package:posternung/core/router/app_routes.dart';

/// Builds the `MaterialApp.router` a widget test should pump, over [routes]
/// and starting at [location].
///
/// Exists because `MaterialApp(home: X)` — what all 27 pumps in this repo
/// used before INF-01 — renders the widget the test named and therefore
/// stays green no matter what the route table says, including when the route
/// that reaches that screen does not exist (ADR-0018 D9, `project-gotchas`
/// §3). Pumping the real table instead makes "is this screen reachable?" a
/// thing a test can fail on.
///
/// [onRouter] hands back the live `GoRouter` so a test can assert on
/// `router.state.uri` — that is how the negative assertion about OTP
/// arguments never reaching a URL is checked.
Widget routedApp({
  required List<RouteBase> routes,
  String location = AppRoutes.onboardingPath,
  Object? extra,
  void Function(GoRouter router)? onRouter,
}) {
  final GoRouter router = GoRouter(
    initialLocation: location,
    initialExtra: extra,
    routes: routes,
  );
  addTearDown(router.dispose);
  onRouter?.call(router);
  return MaterialApp.router(routerConfig: router);
}

/// The app's real route table with the `/` entry replaced by [screen].
///
/// For tests whose subject is a screen rather than its reachability: the
/// screen under test sits at `/`, and every *other* real route is still
/// there, so anything it pushes lands on the destination the app would
/// actually reach rather than on a stand-in the test invented.
List<RouteBase> routesHosting(Widget screen) {
  final List<RouteBase> rest = appRoutes
      .where(
        (RouteBase route) =>
            route is! GoRoute || route.path != AppRoutes.onboardingPath,
      )
      .toList();
  assert(
    rest.length == appRoutes.length - 1,
    'expected exactly one route at ${AppRoutes.onboardingPath} to replace',
  );
  return <RouteBase>[
    GoRoute(
      path: AppRoutes.onboardingPath,
      builder: (BuildContext context, GoRouterState state) => screen,
    ),
    ...rest,
  ];
}
