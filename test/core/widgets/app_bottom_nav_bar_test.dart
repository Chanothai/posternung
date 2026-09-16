import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:posternung/core/router/app_routes.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/core/theme/app_colors.dart';
import 'package:posternung/core/widgets/app_bottom_nav_bar.dart';

import '../../support/router_harness.dart';

/// Minimal real-path routes for exercising [AppBottomNavBar] in isolation —
/// deliberately not the app's full `appRoutes` (which would drag in
/// `AuthGate`, `HomePostersViewModel`'s repository call, etc., none of
/// which this widget's own behaviour depends on). The *paths* are still the
/// real [AppRoutes] constants, so a tap here proves the nav bar names a
/// location the app table actually declares, not one this test invented.
List<RouteBase> _navBarRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoutes.homePath,
    name: AppRoutes.homeName,
    builder: (BuildContext context, GoRouterState state) =>
        const Scaffold(bottomNavigationBar: AppBottomNavBar()),
  ),
  GoRoute(
    path: AppRoutes.ordersPath,
    name: AppRoutes.ordersName,
    builder: (BuildContext context, GoRouterState state) =>
        const Scaffold(bottomNavigationBar: AppBottomNavBar()),
  ),
  GoRoute(
    path: AppRoutes.profilePath,
    name: AppRoutes.profileName,
    builder: (BuildContext context, GoRouterState state) =>
        const Scaffold(bottomNavigationBar: AppBottomNavBar()),
  ),
];

void main() {
  Widget wrap({
    String location = AppRoutes.homePath,
    void Function(GoRouter router)? onRouter,
  }) => routedApp(
    routes: _navBarRoutes(),
    location: location,
    onRouter: onRouter,
  );

  testWidgets(
    'exactly 3 tabs — closed-world: search/wishlist/cart did not survive '
    'the cut to 3 (ADR-0037 Amendment 1)',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.homeNavHome), findsOneWidget);
      expect(find.text(AppStrings.homeNavOrders), findsOneWidget);
      expect(find.text(AppStrings.homeNavProfile), findsOneWidget);
      // Named literally rather than via a since-deleted AppStrings constant
      // — the point of this assertion is that these words are gone from
      // the widget, so it must not resolve them through a constant that
      // no longer exists either.
      expect(find.text('ค้นหา'), findsNothing);
      expect(find.text('รายการที่ชอบ'), findsNothing);
      expect(find.text('ตะกร้าสินค้า'), findsNothing);
      expect(find.byType(InkWell), findsNWidgets(3));
    },
  );

  testWidgets('tapping the orders tab navigates to AppRoutes.ordersPath', (
    tester,
  ) async {
    late GoRouter router;
    await tester.pumpWidget(wrap(onRouter: (GoRouter r) => router = r));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.homeNavOrders));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppRoutes.ordersPath);
  });

  testWidgets('tapping the profile tab navigates to AppRoutes.profilePath', (
    tester,
  ) async {
    late GoRouter router;
    await tester.pumpWidget(wrap(onRouter: (GoRouter r) => router = r));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.homeNavProfile));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppRoutes.profilePath);
  });

  testWidgets('tapping the home tab from another tab navigates back to '
      'AppRoutes.homePath', (tester) async {
    late GoRouter router;
    await tester.pumpWidget(
      wrap(
        location: AppRoutes.ordersPath,
        onRouter: (GoRouter r) => router = r,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.homeNavHome));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppRoutes.homePath);
  });

  testWidgets(
    'the tab matching the current location is tinted accent; the others '
    'are not',
    (tester) async {
      await tester.pumpWidget(wrap(location: AppRoutes.ordersPath));
      await tester.pumpAndSettle();

      Color colorOf(String label) =>
          tester.widget<Text>(find.text(label)).style!.color!;

      expect(colorOf(AppStrings.homeNavOrders), AppColors.accent);
      expect(colorOf(AppStrings.homeNavHome), AppColors.textPrimary);
      expect(colorOf(AppStrings.homeNavProfile), AppColors.textPrimary);
    },
  );
}
