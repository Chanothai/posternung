import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:posternung/core/router/app_router.dart';
import 'package:posternung/core/router/app_routes.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/auth/presentation/providers/session_provider.dart';
import 'package:posternung/features/auth/presentation/screens/login_screen.dart';

import 'package:posternung/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:posternung/features/onboarding/presentation/screens/onboarding_page_view_screen.dart';

import '../../../../support/router_harness.dart';

/// A no-op stand-in for the real view model: leaving onboarding lands on
/// `AppRoutes.homePath`, whose `AuthGate` renders `LoginScreen` when signed
/// out, and the real `AuthViewModel` would reach for Firebase at build time.
class _NoopAuthViewModel extends AuthViewModel {
  @override
  FutureOr<void> build() {}
}

void main() {
  testWidgets('renders the first page copy, CTA, and skip action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingPageViewScreen())),
    );

    expect(find.text('PosterNung'), findsOneWidget);
    expect(
      find.text(
        'เป็นเจ้าของชิ้นส่วนหนึ่งของ\nประวัติศาสตร์ภาพยนตร์',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('ถัดไป'), findsOneWidget);
    expect(find.text('ข้าม'), findsOneWidget);
  });

  testWidgets('tapping Next advances page 1 to page 2', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingPageViewScreen()),
      ),
    );

    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();

    expect(container.read(onboardingControllerProvider), 1);
  });

  testWidgets(
    'tapping Next on the last page shows Get Started and hides skip',
    (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: OnboardingPageViewScreen()),
        ),
      );

      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();

      expect(container.read(onboardingControllerProvider), 2);
      expect(find.text('เริ่มต้นใช้งาน'), findsOneWidget);

      final skip = tester.widget<Opacity>(
        find.ancestor(of: find.text('ข้าม'), matching: find.byType(Opacity)),
      );
      expect(skip.opacity, 0);
    },
  );

  testWidgets('swiping the PageView advances to the next page', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingPageViewScreen()),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(container.read(onboardingControllerProvider), 1);
  });

  testWidgets(
    'finishing onboarding replaces it rather than stacking on top of it — '
    'back from the destination must not walk the user through the intro '
    'again, and system back is the one thing no test here can observe '
    '(project-gotchas §5), so the stack shape is asserted instead',
    (WidgetTester tester) async {
      late GoRouter router;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
            sessionProvider.overrideWithValue(const AsyncData<AuthUser?>(null)),
          ],
          child: routedApp(
            location: AppRoutes.onboardingPath,
            routes: appRoutes,
            onRouter: (r) => router = r,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPageViewScreen), findsOneWidget);

      // Walk to the last page and use the real CTA, not a direct `go`.
      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เริ่มต้นใช้งาน'));
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), AppRoutes.homePath);
      expect(find.byType(OnboardingPageViewScreen), findsNothing);
      // Signed out, so the gate shows login — either way, onboarding is gone
      // from the stack, not merely covered by something.
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        router.canPop(),
        isFalse,
        reason: 'onboarding must be replaced, never pushed past',
      );
    },
  );
}
