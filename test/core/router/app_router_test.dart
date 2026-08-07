import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/catalog_exception.dart';
import 'package:posternung/core/router/app_navigation.dart';
import 'package:posternung/core/router/app_router.dart';
import 'package:posternung/core/router/app_routes.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/presentation/otp_route_args.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/auth/presentation/providers/session_provider.dart';
import 'package:posternung/features/auth/presentation/screens/login_screen.dart';
import 'package:posternung/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:posternung/features/auth/presentation/screens/register_screen.dart';
import 'package:posternung/features/home/presentation/screens/home_screen.dart';
import 'package:posternung/features/onboarding/presentation/screens/onboarding_page_view_screen.dart';
import 'package:posternung/features/poster/domain/entities/paginated_posters.dart';
import 'package:posternung/features/poster/domain/repositories/poster_repository.dart';
import 'package:posternung/features/poster/presentation/providers/poster_providers.dart';
import 'package:posternung/features/poster/presentation/screens/poster_detail_screen.dart';

import '../../support/router_harness.dart';

class _MockPosterRepository extends Mock implements PosterRepository {}

/// A stand-in for the real view model — `LoginScreen` and the OTP screen
/// both read `authViewModelProvider`, and the real one talks to Firebase at
/// build time.
class _NoopAuthViewModel extends AuthViewModel {
  @override
  FutureOr<void> build() {}
}

void main() {
  const uuid = '33333333-3333-4333-8333-333333333333';
  const phoneNumber = '+66812345678';
  const verificationId = 'verification-id-abc123';
  const resendToken = 987654;

  late _MockPosterRepository repository;

  setUp(() {
    repository = _MockPosterRepository();
    when(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async =>
          const PaginatedPosters(items: [], total: 0, limit: 20, offset: 0),
    );
    when(
      () => repository.getPosterDetail(any()),
    ).thenThrow(const CatalogException(code: 'network_error'));
  });

  /// [session] is left off where the test never reaches `AuthGate`; passing
  /// it is how a test says which side of the gate it is about. (Riverpod 3
  /// does not export the `Override` type, so the list is built here rather
  /// than handed in.)
  Future<GoRouter> pumpAt(
    WidgetTester tester,
    String location, {
    Object? extra,
    AsyncValue<AuthUser?>? session,
  }) async {
    late GoRouter router;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
          posterRepositoryProvider.overrideWithValue(repository),
          if (session != null) sessionProvider.overrideWithValue(session),
        ],
        child: routedApp(
          location: location,
          extra: extra,
          routes: appRoutes,
          onRouter: (GoRouter r) => router = r,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  group('AC-3 — the table is the one source of paths', () {
    test('no two routes share a path', () {
      expect(
        AppRoutes.allPaths.toSet(),
        hasLength(AppRoutes.allPaths.length),
        reason: 'duplicate path pattern in AppRoutes.allPaths',
      );
    });

    test('no two routes share a name', () {
      expect(AppRoutes.allNames.toSet(), hasLength(AppRoutes.allNames.length));
    });

    test('the real route table declares exactly the declared constants — a '
        'route added without a constant, or a constant with no route, fails '
        'here rather than creating a second source of truth', () {
      final List<String> tablePaths = appRoutes
          .whereType<GoRoute>()
          .map((GoRoute r) => r.path)
          .toList();
      final List<String?> tableNames = appRoutes
          .whereType<GoRoute>()
          .map((GoRoute r) => r.name)
          .toList();

      expect(tablePaths, hasLength(AppRoutes.allPaths.length));
      expect(tablePaths.toSet(), AppRoutes.allPaths.toSet());
      expect(tableNames.toSet(), AppRoutes.allNames.toSet());
      expect(appRoutes, hasLength(AppRoutes.allPaths.length));
    });
  });

  group('AC-4 — every route is reachable by typing its path', () {
    testWidgets('${AppRoutes.onboardingPath} is onboarding', (tester) async {
      await pumpAt(tester, AppRoutes.onboardingPath);
      expect(find.byType(OnboardingPageViewScreen), findsOneWidget);
    });

    testWidgets('${AppRoutes.homePath} is the gate — signed in it is Home', (
      tester,
    ) async {
      await pumpAt(
        tester,
        AppRoutes.homePath,
        session: const AsyncData<AuthUser?>(
          AuthUser(uid: 'u1', email: 'a@b.co'),
        ),
      );
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets(
      '${AppRoutes.homePath} signed out is LoginScreen — posters stay behind '
      'the gate this round even though the contract marks them public '
      '(ADR-0018 D4, AC-10)',
      (tester) async {
        await pumpAt(
          tester,
          AppRoutes.homePath,
          session: const AsyncData<AuthUser?>(null),
        );
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
      },
    );

    testWidgets('${AppRoutes.registerPath} is the register screen', (
      tester,
    ) async {
      await pumpAt(tester, AppRoutes.registerPath);
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('${AppRoutes.otpPath} with its extra is the OTP screen, and '
        'the screen gets the values that were handed to the route', (
      tester,
    ) async {
      await pumpAt(
        tester,
        AppRoutes.otpPath,
        extra: const OtpRouteArgs(
          phoneNumber: phoneNumber,
          verificationId: verificationId,
          resendToken: resendToken,
        ),
      );

      expect(find.byType(OtpVerificationScreen), findsOneWidget);
      final OtpVerificationScreen screen = tester.widget<OtpVerificationScreen>(
        find.byType(OtpVerificationScreen),
      );
      expect(screen.phoneNumber, phoneNumber);
      expect(screen.verificationId, verificationId);
      expect(screen.resendToken, resendToken);
    });

    testWidgets('/posters/<uuid> reaches the detail screen carrying that '
        'exact uuid — not a synthesized id, and not the literal ":posterId"', (
      tester,
    ) async {
      await pumpAt(tester, AppRoutes.posterDetail(uuid));

      expect(find.byType(PosterDetailScreen), findsOneWidget);
      expect(
        tester
            .widget<PosterDetailScreen>(find.byType(PosterDetailScreen))
            .posterId,
        uuid,
      );
      // Read through the whole real chain rather than only off the widget:
      // the id has to survive as far as the request that uses it.
      verify(() => repository.getPosterDetail(uuid)).called(1);
    });

    testWidgets('a different uuid in the path reaches a different poster — '
        'the parameter is read, not ignored', (tester) async {
      const other = '44444444-4444-4444-8444-444444444444';
      await pumpAt(tester, AppRoutes.posterDetail(other));

      expect(
        tester
            .widget<PosterDetailScreen>(find.byType(PosterDetailScreen))
            .posterId,
        other,
      );
      verify(() => repository.getPosterDetail(other)).called(1);
      verifyNever(() => repository.getPosterDetail(uuid));
    });
  });

  group('AC-5 — nothing secret is ever in a URL', () {
    testWidgets('standing on the OTP screen, the location holds neither the '
        'phone number, the verification id, nor the resend token — in the '
        'path or in a query string (ADR-0018 D6)', (tester) async {
      final GoRouter router = await pumpAt(
        tester,
        AppRoutes.otpPath,
        extra: const OtpRouteArgs(
          phoneNumber: phoneNumber,
          verificationId: verificationId,
          resendToken: resendToken,
        ),
      );

      // The screen really is up — otherwise this asserts about a URL nobody
      // is on.
      expect(find.byType(OtpVerificationScreen), findsOneWidget);

      final Uri uri = router.state.uri;
      final String location = uri.toString();
      expect(location, AppRoutes.otpPath);
      expect(location, isNot(contains(phoneNumber)));
      // Without the leading '+', too: a URL-encoded or stripped form would
      // still be a leak.
      expect(location, isNot(contains(phoneNumber.substring(1))));
      expect(location, isNot(contains(verificationId)));
      expect(location, isNot(contains('$resendToken')));
      expect(uri.queryParameters, isEmpty);
      expect(uri.fragment, isEmpty);
    });

    test('no path pattern in the table names any of the three', () {
      for (final String path in AppRoutes.allPaths) {
        expect(path, isNot(contains('phone')));
        expect(path, isNot(contains('verification')));
        expect(path, isNot(contains('resend')));
        expect(path, isNot(contains('token')));
        expect(path, isNot(contains('?')));
      }
    });
  });

  group('AC-6 — back behaviour', () {
    testWidgets('poster detail pops back to where it was opened from', (
      tester,
    ) async {
      final GoRouter router = await pumpAt(
        tester,
        AppRoutes.homePath,
        session: const AsyncData<AuthUser?>(
          AuthUser(uid: 'u1', email: 'a@b.co'),
        ),
      );

      router.push(AppRoutes.posterDetail(uuid));
      await tester.pumpAndSettle();
      expect(find.byType(PosterDetailScreen), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(PosterDetailScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(router.state.uri.toString(), AppRoutes.homePath);
    });

    testWidgets('register is pushed, not gone to — back returns to the gate '
        'rather than leaving the user with nowhere to go', (tester) async {
      final GoRouter router = await pumpAt(
        tester,
        AppRoutes.homePath,
        session: const AsyncData<AuthUser?>(null),
      );

      router.push(AppRoutes.registerPath);
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(router.canPop(), isTrue);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('the /otp route cannot be entered without its arguments', () {
    testWidgets('arriving at /otp with no extra lands on home instead of '
        'throwing — extra does not survive a process restore, and the screen '
        'cannot exist without it', (tester) async {
      final GoRouter router = await pumpAt(
        tester,
        AppRoutes.otpPath,
        session: const AsyncData<AuthUser?>(null),
      );

      expect(find.byType(OtpVerificationScreen), findsNothing);
      expect(router.state.uri.toString(), AppRoutes.homePath);
      expect(tester.takeException(), isNull);
    });

    testWidgets('arriving at /otp with the wrong kind of extra also lands on '
        'home rather than reaching the single cast', (tester) async {
      final GoRouter router = await pumpAt(
        tester,
        AppRoutes.otpPath,
        extra: 'not-the-args-object',
        session: const AsyncData<AuthUser?>(null),
      );

      expect(find.byType(OtpVerificationScreen), findsNothing);
      expect(router.state.uri.toString(), AppRoutes.homePath);
      expect(tester.takeException(), isNull);
    });
  });

  group('refreshing while standing on /otp', () {
    testWidgets('a GoRouter.refresh() does not put a crash on the screen — '
        'it rebuilds this route with extra dropped and does NOT re-run the '
        'redirect, so the builder has to cope on its own', (tester) async {
      final GoRouter router = await pumpAt(
        tester,
        AppRoutes.homePath,
        session: const AsyncData<AuthUser?>(null),
      );
      router.push(
        AppRoutes.otpPath,
        extra: const OtpRouteArgs(
          phoneNumber: phoneNumber,
          verificationId: verificationId,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OtpVerificationScreen), findsOneWidget);

      router.refresh();
      await tester.pumpAndSettle();

      // The important half: no exception reached the frame. Before this was
      // handled, `state.extra! as OtpRouteArgs` threw "Null check operator
      // used on a null value" right here.
      expect(tester.takeException(), isNull);
      expect(find.byType(OtpVerificationScreen), findsNothing);
      expect(router.state.uri.toString(), AppRoutes.homePath);
    });

    testWidgets('the same holds when a refreshListenable fires — that is the '
        'shape a route-level auth guard needs (ADR-0018 §ต้องทำตามมา 2), so '
        'this path becomes live next round', (tester) async {
      final ChangeNotifier notifier = ChangeNotifier();
      addTearDown(notifier.dispose);
      final GoRouter router = GoRouter(
        initialLocation: AppRoutes.homePath,
        routes: appRoutes,
        refreshListenable: notifier,
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
            posterRepositoryProvider.overrideWithValue(repository),
            sessionProvider.overrideWithValue(const AsyncData<AuthUser?>(null)),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      router.push(
        AppRoutes.otpPath,
        extra: const OtpRouteArgs(
          phoneNumber: phoneNumber,
          verificationId: verificationId,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OtpVerificationScreen), findsOneWidget);

      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      notifier.notifyListeners();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(router.state.uri.toString(), AppRoutes.homePath);
    });
  });

  group('popOrGoHome', () {
    testWidgets('pops when there is something to pop', (tester) async {
      final GoRouter router = await pumpAt(
        tester,
        AppRoutes.homePath,
        session: const AsyncData<AuthUser?>(
          AuthUser(uid: 'u1', email: 'a@b.co'),
        ),
      );
      router.push(AppRoutes.posterDetail(uuid));
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(
        find.byType(PosterDetailScreen),
      );
      context.popOrGoHome();
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), AppRoutes.homePath);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('goes home instead of throwing when the screen is the only '
        'one on the stack', (tester) async {
      final GoRouter router = await pumpAt(
        tester,
        AppRoutes.posterDetail(uuid),
        session: const AsyncData<AuthUser?>(null),
      );
      expect(router.canPop(), isFalse);

      final BuildContext context = tester.element(
        find.byType(PosterDetailScreen),
      );
      context.popOrGoHome();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(router.state.uri.toString(), AppRoutes.homePath);
    });
  });
}
