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
import 'package:posternung/core/router/route_state_guard.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/auth/presentation/providers/otp_flow_provider.dart';
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

import '../../support/otp_flow_harness.dart';
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
  /// [otpFlow] seeds `otpFlowProvider`, which is how a test says the phone
  /// verification flow is open. It replaces the `extra:` this helper used to
  /// take: after Amendment 2 no route carries arguments, so there is nothing
  /// to hand the router.
  Future<GoRouter> pumpAt(
    WidgetTester tester,
    String location, {
    OtpFlowState? otpFlow,
    AsyncValue<AuthUser?>? session,
    List<RouteBase>? routes,
  }) async {
    late GoRouter router;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
          posterRepositoryProvider.overrideWithValue(repository),
          otpFlowProvider.overrideWith(() => SeededOtpFlow(otpFlow)),
          if (session != null) sessionProvider.overrideWithValue(session),
        ],
        child: routedApp(
          location: location,
          routes: routes ?? appRoutes,
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

    testWidgets('${AppRoutes.otpPath} with an open flow is the OTP screen, '
        'and the screen shows the number the flow is for', (tester) async {
      await pumpAt(
        tester,
        AppRoutes.otpPath,
        otpFlow: const OtpFlowState(
          phoneNumber: phoneNumber,
          verificationId: verificationId,
          resendToken: resendToken,
        ),
      );

      expect(find.byType(OtpVerificationScreen), findsOneWidget);
      expect(
        tester
            .widget<OtpVerificationScreen>(find.byType(OtpVerificationScreen))
            .phoneNumber,
        phoneNumber,
      );
      // `verificationId`/`resendToken` are deliberately not readable off the
      // widget any more — the screen reads them from the flow at the moment
      // it uses them. That they are the *current* ones is proved where it
      // matters, against a real submit, in
      // `otp_verification_screen_test.dart`.
      expect(find.text(phoneNumber), findsOneWidget);
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

  // 🔴 After Amendment 2 (A2-D7) these hold *structurally*: the route carries
  // no arguments at all, so there is nothing for a URL to leak. They are kept
  // as a guard against the day someone puts a value back on the route — not
  // as evidence that this round made anything safer than INF-01 left it.
  group('AC-5 — nothing secret is ever in a URL', () {
    testWidgets('standing on the OTP screen, the location holds neither the '
        'phone number, the verification id, nor the resend token — in the '
        'path or in a query string (ADR-0018 D6)', (tester) async {
      final GoRouter router = await pumpAt(
        tester,
        AppRoutes.otpPath,
        otpFlow: const OtpFlowState(
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

  group('a route that needs state it does not have leaves for home', () {
    testWidgets('arriving at /otp with no flow open lands on home instead of '
        'throwing — a deep link or a process restore both arrive this way, '
        'and the screen cannot exist without a flow', (tester) async {
      final GoRouter router = await pumpAt(
        tester,
        AppRoutes.otpPath,
        session: const AsyncData<AuthUser?>(null),
      );

      expect(find.byType(OtpVerificationScreen), findsNothing);
      expect(router.state.uri.toString(), AppRoutes.homePath);
      expect(tester.takeException(), isNull);
    });

    testWidgets('going to /otp from inside the app with no flow open lands '
        'on home too — `go` and a cold arrival take different paths through '
        'the router and both have to end somewhere real', (tester) async {
      final GoRouter router = await pumpAt(
        tester,
        AppRoutes.homePath,
        session: const AsyncData<AuthUser?>(null),
      );
      expect(find.byType(LoginScreen), findsOneWidget);

      router.go(AppRoutes.otpPath);
      await tester.pumpAndSettle();

      expect(find.byType(OtpVerificationScreen), findsNothing);
      expect(router.state.uri.toString(), AppRoutes.homePath);
      expect(tester.takeException(), isNull);
    });
  });

  group('INF-18 AC-1 — refreshing while standing on /otp keeps the flow', () {
    // 🔴 Arrive with `push`, never with `initialLocation`. The initial-parse
    // path re-evaluates `redirect` and bounces politely, so a probe built
    // that way reports "no problem" for a route that crashes in the app
    // (`project-gotchas` §5 — this is a recorded measurement failure, not a
    // hypothetical one).
    testWidgets('a GoRouter.refresh() rebuilds the route with the flow still '
        'open — the user stays on /otp and the screen still shows the number '
        'the code was sent to', (tester) async {
      final GoRouter router = await pumpAt(
        tester,
        AppRoutes.homePath,
        session: const AsyncData<AuthUser?>(null),
        otpFlow: const OtpFlowState(
          phoneNumber: phoneNumber,
          verificationId: verificationId,
        ),
      );
      router.push(AppRoutes.otpPath);
      await tester.pumpAndSettle();
      expect(find.byType(OtpVerificationScreen), findsOneWidget);

      router.refresh();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Before Amendment 2 all three of these were the opposite: the route
      // rebuilt with its `extra` dropped to null and the user was thrown out
      // to /home in the middle of entering a code.
      expect(find.byType(OtpVerificationScreen), findsOneWidget);
      expect(router.state.uri.toString(), AppRoutes.otpPath);
      expect(find.text(phoneNumber), findsOneWidget);
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
            otpFlowProvider.overrideWith(
              () => SeededOtpFlow(
                const OtpFlowState(
                  phoneNumber: phoneNumber,
                  verificationId: verificationId,
                ),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      router.push(AppRoutes.otpPath);
      await tester.pumpAndSettle();
      expect(find.byType(OtpVerificationScreen), findsOneWidget);

      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      notifier.notifyListeners();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(OtpVerificationScreen), findsOneWidget);
      expect(router.state.uri.toString(), AppRoutes.otpPath);
    });
  });

  group('INF-18 AC-6 — the guard is central, not something /otp owns', () {
    // The defect BL-100 actually recorded was not the crash on `/otp`; it was
    // that the next route to need state had nothing to inherit and no way to
    // find out. So the proof is a *second* route going through the same
    // helper and surviving the same refresh — if `requireRouteState` were
    // really `/otp`'s private workaround wearing a shared name, this fails
    // while the tests above still pass.
    const String otherPath = '/needs-state';

    List<RouteBase> tableWithSecondGuardedRoute() => <RouteBase>[
      ...appRoutes,
      GoRoute(
        path: otherPath,
        builder: (BuildContext context, GoRouterState state) => Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? _) =>
              requireRouteState<OtpFlowState>(
                context,
                ref.read(otpFlowProvider),
                builder: (OtpFlowState flow) =>
                    Scaffold(body: Text('second:${flow.phoneNumber}')),
              ),
        ),
      ),
    ];

    testWidgets('a second route built on requireRouteState also survives a '
        'refresh with its state intact', (tester) async {
      final GoRouter router = await pumpAt(
        tester,
        AppRoutes.homePath,
        session: const AsyncData<AuthUser?>(null),
        routes: tableWithSecondGuardedRoute(),
        otpFlow: const OtpFlowState(
          phoneNumber: phoneNumber,
          verificationId: verificationId,
        ),
      );

      router.push(otherPath);
      await tester.pumpAndSettle();
      expect(find.text('second:$phoneNumber'), findsOneWidget);

      router.refresh();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('second:$phoneNumber'), findsOneWidget);
      expect(router.state.uri.toString(), otherPath);
    });

    testWidgets('and that second route leaves for home when the state is '
        'missing, without anyone writing a fallback for it', (tester) async {
      final GoRouter router = await pumpAt(
        tester,
        AppRoutes.homePath,
        session: const AsyncData<AuthUser?>(null),
        routes: tableWithSecondGuardedRoute(),
      );

      router.push(otherPath);
      await tester.pumpAndSettle();

      expect(find.text('second:$phoneNumber'), findsNothing);
      expect(router.state.uri.toString(), AppRoutes.homePath);
      expect(tester.takeException(), isNull);
    });
  });

  group('INF-18 AC-3 — the flow ends when the user leaves, and only then', () {
    // Pumped through `routerProvider`, not through `routedApp`: the observer
    // that does the clearing is installed by the provider, so a hand-built
    // router would test a wiring the app does not have.
    late ProviderContainer container;

    Future<GoRouter> pumpOnOtp(WidgetTester tester) async {
      late GoRouter router;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
            posterRepositoryProvider.overrideWithValue(repository),
            sessionProvider.overrideWithValue(const AsyncData<AuthUser?>(null)),
            otpFlowProvider.overrideWith(
              () => SeededOtpFlow(
                const OtpFlowState(
                  phoneNumber: phoneNumber,
                  verificationId: verificationId,
                ),
              ),
            ),
          ],
          child: appWithRealRouter(onRouter: (GoRouter r) => router = r),
        ),
      );
      await tester.pumpAndSettle();
      container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      router.go(AppRoutes.homePath);
      await tester.pumpAndSettle();
      router.push(AppRoutes.otpPath);
      await tester.pumpAndSettle();
      expect(find.byType(OtpVerificationScreen), findsOneWidget);
      expect(container.read(otpFlowProvider), isNotNull);
      return router;
    }

    testWidgets('🔴 a refresh does NOT end the flow — this is the case that '
        'GoRoute.onExit and State.dispose() both get wrong, because both fire '
        'on a rebuild the user never asked for', (tester) async {
      final GoRouter router = await pumpOnOtp(tester);

      router.refresh();
      await tester.pumpAndSettle();

      expect(
        container.read(otpFlowProvider),
        isNotNull,
        reason: 'refresh cleared the flow the user is still standing in',
      );
      expect(container.read(otpFlowProvider)!.verificationId, verificationId);
      expect(find.byType(OtpVerificationScreen), findsOneWidget);
    });

    testWidgets('backing out of /otp ends the flow', (tester) async {
      final GoRouter router = await pumpOnOtp(tester);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.byType(OtpVerificationScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        container.read(otpFlowProvider),
        isNull,
        reason: 'the flow outlived the screen it belongs to',
      );
    });

    testWidgets('leaving /otp by going home — the shape a successful '
        'verification takes — ends it too', (tester) async {
      final GoRouter router = await pumpOnOtp(tester);

      router.go(AppRoutes.homePath);
      await tester.pumpAndSettle();

      expect(find.byType(OtpVerificationScreen), findsNothing);
      expect(container.read(otpFlowProvider), isNull);
    });

    testWidgets('popping something that was pushed *on top of* /otp leaves '
        'the flow alone — the observer fires for every route, so without the '
        'name check a dialog or a sheet closing would end a flow the user is '
        'still standing in', (tester) async {
      final GoRouter router = await pumpOnOtp(tester);

      router.push(AppRoutes.registerPath);
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.byType(OtpVerificationScreen), findsOneWidget);
      expect(
        container.read(otpFlowProvider),
        isNotNull,
        reason: 'a pop of a different route ended the OTP flow',
      );
    });

    testWidgets('clearing the flow while /otp is on screen does not move the '
        'user — the route reads its state once at build (`read`, not '
        '`watch`), so nothing re-guards a route the user has not left', (
      tester,
    ) async {
      await pumpOnOtp(tester);

      container.read(otpFlowProvider.notifier).clear();
      await tester.pumpAndSettle();

      // With a `watch` here the route rebuilds, finds no state, and sends the
      // user to home mid-flow — the failure `requireRouteState`'s doc comment
      // describes, and the reason that choice is not a style preference.
      expect(find.byType(OtpVerificationScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
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
