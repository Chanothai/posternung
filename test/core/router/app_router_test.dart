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
import 'package:posternung/features/auth/presentation/providers/email_verification_flow_provider.dart';
import 'package:posternung/features/auth/presentation/providers/otp_flow_provider.dart';
import 'package:posternung/features/auth/presentation/providers/session_provider.dart';
import 'package:posternung/features/auth/presentation/screens/email_verification_screen.dart';
import 'package:posternung/features/auth/presentation/screens/login_screen.dart';
import 'package:posternung/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:posternung/features/auth/presentation/screens/register_screen.dart';
import 'package:posternung/features/checkout/domain/entities/order.dart';
import 'package:posternung/features/checkout/domain/entities/order_status.dart';
import 'package:posternung/features/checkout/domain/entities/reservation.dart';
import 'package:posternung/features/checkout/presentation/providers/checkout_flow_provider.dart';
import 'package:posternung/features/checkout/presentation/providers/checkout_view_model.dart';
import 'package:posternung/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:posternung/features/checkout/presentation/state/checkout_state.dart';
import 'package:posternung/features/checkout/presentation/widgets/checkout_address_form.dart';
import 'package:posternung/features/checkout/presentation/widgets/checkout_order_created_view.dart';
import 'package:posternung/features/checkout/presentation/widgets/checkout_reservation_lost_view.dart';
import 'package:posternung/features/home/presentation/screens/home_screen.dart';
import 'package:posternung/features/onboarding/presentation/screens/onboarding_page_view_screen.dart';
import 'package:posternung/features/orders/presentation/screens/orders_placeholder_screen.dart';
import 'package:posternung/features/poster/domain/entities/paginated_posters.dart';
import 'package:posternung/features/poster/domain/entities/poster_detail.dart';
import 'package:posternung/features/poster/domain/entities/poster_status.dart';
import 'package:posternung/features/poster/domain/repositories/poster_repository.dart';
import 'package:posternung/features/poster/presentation/providers/poster_providers.dart';
import 'package:posternung/features/poster/presentation/screens/poster_detail_screen.dart';
import 'package:posternung/features/privacy/presentation/screens/privacy_screen.dart';
import 'package:posternung/features/profile/presentation/screens/profile_screen.dart';

import '../../support/checkout_flow_harness.dart';
import '../../support/email_verification_flow_harness.dart';
import '../../support/manual_stopwatch.dart';
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

PosterDetail _poster() => PosterDetail(
  id: 'p1',
  title: 'Blade Runner',
  price: '450.00',
  status: PosterStatus.available,
  conditionGrade: null,
  eraDecade: 1980,
  studio: 'Warner Bros',
  primaryImageUrl: null,
  tmdbId: null,
  size: null,
  description: null,
  isAuthenticated: true,
  authenticityNote: null,
  provenance: null,
  images: const [],
  createdAt: DateTime(2024),
  posterType: null,
  releaseRegion: null,
  releaseDateText: null,
  releaseDate: null,
  copyrightYear: null,
  sizeFormat: null,
  year: null,
  restorationStatus: null,
  restorationNote: null,
);

/// SCR-07 B1 — a checkout flow with a real span, backed by a
/// [ManualStopwatch] so nothing in this file's `Timer.periodic` (owned by
/// `reservationCountdownProvider`, mounted with `CheckoutScreen`) ticks
/// against real wall-clock time during a reachability test.
CheckoutFlowState _checkoutFlow() {
  final createdAt = DateTime.utc(2026, 9, 16, 15, 30);
  return CheckoutFlowState(
    reservation: Reservation(
      id: 'r1',
      posterId: 'p1',
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(minutes: 30)),
    ),
    posterSnapshot: _poster(),
    stopwatch: ManualStopwatch(),
  );
}

/// F1/F2 — a placed order, for tests that drive `checkoutViewModelProvider`
/// straight to `CheckoutOrderCreated` without going through a real
/// `POST /orders` call (that path is covered in `checkout_view_model_test.
/// dart`/`checkout_screen_test.dart`; this file's subject is state lifecycle
/// across navigation).
Order _order() => Order(
  id: 'o1',
  orderNo: 'PN-260916-0001',
  posterId: 'p1',
  status: OrderStatus.awaitingPayment,
  itemPrice: '450.00',
  shippingFee: '0.00',
  totalAmount: '450.00',
  itemTitle: 'Blade Runner',
  createdAt: DateTime.utc(2026, 9, 16),
);

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
  /// [checkoutFlow] seeds `checkoutFlowProvider`, same idea as [otpFlow] —
  /// how a test says the checkout flow is open before arriving at
  /// `/checkout`.
  ///
  /// 🔴 [settle] defaults to `true` (`pumpAndSettle`), but **must be passed
  /// `false` for any test that reaches `/checkout`**: that screen owns a
  /// `Timer.periodic` (`reservationCountdownProvider`), and
  /// `pumpAndSettle` waits for the widget tree to go idle — which a
  /// repeating timer never does, hanging the test (GATE 1 §1 — the exact
  /// trap `app_router_test.dart:102` documents). Pass `settle: false` and
  /// drive time explicitly with `tester.pump(Duration(...))` instead.
  Future<GoRouter> pumpAt(
    WidgetTester tester,
    String location, {
    OtpFlowState? otpFlow,
    EmailVerificationFlowState? emailVerificationFlow,
    CheckoutFlowState? checkoutFlow,
    AsyncValue<AuthUser?>? session,
    List<RouteBase>? routes,
    bool settle = true,
  }) async {
    late GoRouter router;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
          posterRepositoryProvider.overrideWithValue(repository),
          otpFlowProvider.overrideWith(() => SeededOtpFlow(otpFlow)),
          emailVerificationFlowProvider.overrideWith(
            () => SeededEmailVerificationFlow(emailVerificationFlow),
          ),
          checkoutFlowProvider.overrideWith(
            () => SeededCheckoutFlow(checkoutFlow),
          ),
          if (session != null) sessionProvider.overrideWithValue(session),
        ],
        child: routedApp(
          location: location,
          routes: routes ?? appRoutes,
          onRouter: (GoRouter r) => router = r,
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
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

    testWidgets('${AppRoutes.emailVerificationPath} with an open flow is the '
        'email-verification screen, showing the email the flow is for '
        '(ADR-0021 D2)', (tester) async {
      const email = 'someone@example.com';
      await pumpAt(
        tester,
        AppRoutes.emailVerificationPath,
        emailVerificationFlow: const EmailVerificationFlowState(
          email: email,
          justSentEmail: false,
        ),
      );

      expect(find.byType(EmailVerificationScreen), findsOneWidget);
      expect(
        tester
            .widget<EmailVerificationScreen>(
              find.byType(EmailVerificationScreen),
            )
            .email,
        email,
      );
      expect(find.text(email), findsOneWidget);
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

    testWidgets(
      '${AppRoutes.ordersPath} is the gate — signed in it is the orders '
      'placeholder (SCR-07 B7)',
      (tester) async {
        await pumpAt(
          tester,
          AppRoutes.ordersPath,
          session: const AsyncData<AuthUser?>(
            AuthUser(uid: 'u1', email: 'a@b.co'),
          ),
        );
        expect(find.byType(OrdersPlaceholderScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
      },
    );

    testWidgets(
      '${AppRoutes.ordersPath} signed out is LoginScreen — same AuthGate '
      'shape as /home',
      (tester) async {
        await pumpAt(
          tester,
          AppRoutes.ordersPath,
          session: const AsyncData<AuthUser?>(null),
        );
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(OrdersPlaceholderScreen), findsNothing);
      },
    );

    testWidgets(
      '${AppRoutes.profilePath} is the gate — signed in it is the profile '
      'screen (SCR-07 B7)',
      (tester) async {
        await pumpAt(
          tester,
          AppRoutes.profilePath,
          session: const AsyncData<AuthUser?>(
            AuthUser(uid: 'u1', email: 'a@b.co'),
          ),
        );
        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
      },
    );

    testWidgets(
      '${AppRoutes.profilePath} signed out is LoginScreen — same AuthGate '
      'shape as /home',
      (tester) async {
        await pumpAt(
          tester,
          AppRoutes.profilePath,
          session: const AsyncData<AuthUser?>(null),
        );
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(ProfileScreen), findsNothing);
      },
    );

    testWidgets(
      '${AppRoutes.checkoutPath} with an open flow is CheckoutScreen, '
      'signed in (SCR-07 B1)',
      (tester) async {
        // `settle: false` — CheckoutScreen owns a Timer.periodic
        // (`reservationCountdownProvider`); `pumpAndSettle` never returns
        // against a repeating timer (this file's own `pumpAt` doc comment).
        await pumpAt(
          tester,
          AppRoutes.checkoutPath,
          session: const AsyncData<AuthUser?>(
            AuthUser(uid: 'u1', email: 'a@b.co'),
          ),
          checkoutFlow: _checkoutFlow(),
          settle: false,
        );
        expect(find.byType(CheckoutScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
      },
    );

    testWidgets(
      '${AppRoutes.checkoutPath} signed out is LoginScreen — same AuthGate '
      'shape as /home',
      (tester) async {
        await pumpAt(
          tester,
          AppRoutes.checkoutPath,
          session: const AsyncData<AuthUser?>(null),
          checkoutFlow: _checkoutFlow(),
          settle: false,
        );
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(CheckoutScreen), findsNothing);
      },
    );

    testWidgets(
      '${AppRoutes.privacyPath} is PrivacyScreen — public, reachable with '
      'no session at all (SCR-07 AC-5)',
      (tester) async {
        await pumpAt(
          tester,
          AppRoutes.privacyPath,
          session: const AsyncData<AuthUser?>(null),
        );
        expect(find.byType(PrivacyScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
      },
    );
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

    testWidgets(
      'arriving at ${AppRoutes.emailVerificationPath} with no flow open '
      'lands on home too — same guard, same reasoning (ADR-0021 D2 reuses '
      'ADR-0018 Amendment 2 A2-D3)',
      (tester) async {
        final GoRouter router = await pumpAt(
          tester,
          AppRoutes.emailVerificationPath,
          session: const AsyncData<AuthUser?>(null),
        );

        expect(find.byType(EmailVerificationScreen), findsNothing);
        expect(router.state.uri.toString(), AppRoutes.homePath);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'arriving at ${AppRoutes.checkoutPath} with no flow open lands on '
      'home instead of throwing — same guard as /otp (SCR-07 B1, ADR-0018 '
      'Amendment 2 A2-D3). Default (settling) pump is safe here: the guard '
      'redirects before CheckoutScreen — and its Timer.periodic — ever '
      'mounts.',
      (tester) async {
        final GoRouter router = await pumpAt(
          tester,
          AppRoutes.checkoutPath,
          session: const AsyncData<AuthUser?>(
            AuthUser(uid: 'u1', email: 'a@b.co'),
          ),
        );

        expect(find.byType(CheckoutScreen), findsNothing);
        expect(router.state.uri.toString(), AppRoutes.homePath);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group(
    'ADR-0021 D2 — refreshing while standing on /verify-email keeps the flow',
    () {
      const email = 'someone@example.com';

      testWidgets(
        'a GoRouter.refresh() rebuilds the route with the flow still open',
        (tester) async {
          final GoRouter router = await pumpAt(
            tester,
            AppRoutes.homePath,
            session: const AsyncData<AuthUser?>(null),
            emailVerificationFlow: const EmailVerificationFlowState(
              email: email,
              justSentEmail: false,
            ),
          );
          router.push(AppRoutes.emailVerificationPath);
          await tester.pumpAndSettle();
          expect(find.byType(EmailVerificationScreen), findsOneWidget);

          router.refresh();
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(EmailVerificationScreen), findsOneWidget);
          expect(router.state.uri.toString(), AppRoutes.emailVerificationPath);
          expect(find.text(email), findsOneWidget);
        },
      );
    },
  );

  group('ADR-0021 D2 — the email-verification flow ends when the user leaves, '
      'and only then', () {
    const email = 'someone@example.com';
    late ProviderContainer container;

    Future<GoRouter> pumpOnEmailVerification(WidgetTester tester) async {
      late GoRouter router;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
            posterRepositoryProvider.overrideWithValue(repository),
            sessionProvider.overrideWithValue(const AsyncData<AuthUser?>(null)),
            emailVerificationFlowProvider.overrideWith(
              () => SeededEmailVerificationFlow(
                const EmailVerificationFlowState(
                  email: email,
                  justSentEmail: false,
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
      router.push(AppRoutes.emailVerificationPath);
      await tester.pumpAndSettle();
      expect(find.byType(EmailVerificationScreen), findsOneWidget);
      expect(container.read(emailVerificationFlowProvider), isNotNull);
      return router;
    }

    testWidgets('a refresh does NOT end the flow', (tester) async {
      final GoRouter router = await pumpOnEmailVerification(tester);

      router.refresh();
      await tester.pumpAndSettle();

      expect(
        container.read(emailVerificationFlowProvider),
        isNotNull,
        reason: 'refresh cleared the flow the user is still standing in',
      );
      expect(find.byType(EmailVerificationScreen), findsOneWidget);
    });

    testWidgets('backing out ends the flow', (tester) async {
      final GoRouter router = await pumpOnEmailVerification(tester);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.byType(EmailVerificationScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        container.read(emailVerificationFlowProvider),
        isNull,
        reason: 'the flow outlived the screen it belongs to',
      );
    });

    testWidgets('leaving by going home — the shape a successful check '
        'takes — ends it too', (tester) async {
      final GoRouter router = await pumpOnEmailVerification(tester);

      router.go(AppRoutes.homePath);
      await tester.pumpAndSettle();

      expect(find.byType(EmailVerificationScreen), findsNothing);
      expect(container.read(emailVerificationFlowProvider), isNull);
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

  group('F1 — checkoutViewModelProvider must not leak state across flows '
      '(it must be .autoDispose)', () {
    late ProviderContainer container;

    // Pumped through `appWithRealRouter`/`routerProvider` — not the
    // observer-less `pumpAt`/`routedApp` — because (b) below needs
    // `CheckoutFlowObserver` genuinely installed and clearing
    // `checkoutFlowProvider` on the real `router.pop()`. A first version of
    // this harness used `pumpAt` and (b) passed for the wrong reason: with
    // no observer wired up, `checkoutFlowProvider` never went null on pop
    // at all, so `_onCountdownExpired`'s guard was never actually exercised
    // — removing it did not turn the test red. Confirmed by running the
    // guard-removal mutation against that version first.
    Future<GoRouter> pumpOnCheckout(WidgetTester tester) async {
      late GoRouter router;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
            posterRepositoryProvider.overrideWithValue(repository),
            sessionProvider.overrideWithValue(
              const AsyncData<AuthUser?>(AuthUser(uid: 'u1', email: 'a@b.co')),
            ),
            checkoutFlowProvider.overrideWith(
              () => SeededCheckoutFlow(_checkoutFlow()),
            ),
          ],
          child: appWithRealRouter(onRouter: (GoRouter r) => router = r),
        ),
      );
      await tester.pump();
      container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      router.go(AppRoutes.homePath);
      await tester.pumpAndSettle();
      router.push(AppRoutes.checkoutPath);
      // Not `pumpAndSettle()` — `/checkout` starts a `Timer.periodic`
      // (`reservationCountdownProvider`) the moment it mounts, which never
      // settles. The extra `pump(Duration(...))` lets the push's
      // page-transition animation run its course instead of leaving
      // `CheckoutScreen` mid-transition.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CheckoutScreen), findsOneWidget);
      return router;
    }

    testWidgets('(a) OrderCreated → back home → reserving a new poster reaches '
        'CheckoutReady for the new flow, not the previous OrderCreatedView. '
        '🔴 mutation-locking: reverting checkoutViewModelProvider to a plain '
        '(non-autoDispose) NotifierProvider turns this red.', (tester) async {
      final GoRouter router = await pumpOnCheckout(tester);

      // Drives the ViewModel straight to the terminal state a real
      // `POST /orders` success would reach — this group's subject is
      // state lifecycle across navigation, not `submit()` itself
      // (covered in `checkout_view_model_test.dart`).
      container.read(checkoutViewModelProvider.notifier).state =
          CheckoutOrderCreated(_order());
      await tester.pump();
      expect(find.byType(CheckoutOrderCreatedView), findsOneWidget);

      router.go(AppRoutes.homePath);
      await tester.pump();
      // Lets `go()`'s page-transition fully finish. `pump(Duration)` runs on
      // the test binding's fake clock, not the wall clock — there is no
      // "sometimes needs longer" here. A duration right after `kThemeAnimation
      // Duration` (~400ms) is deterministically still mid-transition with the
      // outgoing `/checkout` page mounted; ~700ms and up is deterministically
      // past it. 2 seconds is used for margin, not because a shorter duration
      // is flaky.
      await tester.pump(const Duration(seconds: 2));

      container.read(checkoutFlowProvider.notifier).start(_checkoutFlow());
      router.push(AppRoutes.checkoutPath);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(CheckoutOrderCreatedView), findsNothing);
      expect(find.byType(CheckoutAddressForm), findsOneWidget);
      expect(
        container.read(checkoutViewModelProvider),
        isA<CheckoutReady>(),
        reason:
            'checkoutViewModelProvider leaked CheckoutOrderCreated from '
            'the previous flow into a brand-new reservation',
      );
    });

    // ✏️ Corrected 2026-09-16 at code-critic round 2 (SCR-07 slice B, N-3).
    // The doc comment used to claim this router-level test could not
    // mutation-lock the guard at all, because `tester.pump()` with no
    // duration doesn't fire the `Future(() {})` `CheckoutFlowObserver.didPop`
    // defers its `checkoutFlowProvider` clearing into — so the popped screen
    // and its ViewModel looked torn down "together" only because the
    // observer's side effect hadn't run yet, not because they actually were.
    // That was never a real timing race; `pump(Duration.zero)` flushes that
    // microtask deterministically. Asserting right there — flow cleared,
    // popped screen's ViewModel still `CheckoutReady`, no
    // `CheckoutReservationLostView` — now does mutation-lock the guard at
    // the router level, confirmed below. The guard's unit-level lock in
    // `checkout_view_model_test.dart`'s "F1 guard" test still stands too;
    // this is not a replacement for it, just no longer a no-op.
    testWidgets(
      '(b) backing out of a Ready checkout, then reserving again fast '
      'enough that the popped ViewModel has not been autoDispose-collected '
      'yet, never flashes ReservationLostView and still reaches Ready — '
      'this is the router-level regression for the scenario the guard '
      'fixes, mutation-locked at this level too (see the group doc comment '
      'above).',
      (tester) async {
        final GoRouter router = await pumpOnCheckout(tester);
        expect(container.read(checkoutViewModelProvider), isA<CheckoutReady>());

        // Deliberately no settling duration between the pop and the next
        // push — this models the "leave, then come straight back" case
        // `.autoDispose`'s grace period exists for.
        router.pop();
        await tester.pump();
        await tester.pump(Duration.zero); // fires the Future() the observer
        // deferred `checkoutFlowProvider` clearing into.
        expect(
          find.byType(CheckoutReservationLostView),
          findsNothing,
          reason:
              'the old screen is still mid pop-transition here — this is '
              "the exact instant the guard this test locks protects: "
              'checkoutFlowProvider is null but the popped ViewModel has '
              'not been autoDispose-collected yet.',
        );
        expect(container.read(checkoutViewModelProvider), isA<CheckoutReady>());

        container.read(checkoutFlowProvider.notifier).start(_checkoutFlow());
        router.push(AppRoutes.checkoutPath);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));

        expect(find.byType(CheckoutReservationLostView), findsNothing);
        expect(container.read(checkoutViewModelProvider), isA<CheckoutReady>());
      },
    );
  });

  group(
    'F2 — CheckoutFlowObserver clears checkoutFlowProvider only on a real '
    'departure from /checkout (ADR-0018 A2-D4, same shape as OtpFlowObserver)',
    () {
      late ProviderContainer container;

      Future<GoRouter> pumpOnCheckout(WidgetTester tester) async {
        late GoRouter router;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
              posterRepositoryProvider.overrideWithValue(repository),
              sessionProvider.overrideWithValue(
                const AsyncData<AuthUser?>(
                  AuthUser(uid: 'u1', email: 'a@b.co'),
                ),
              ),
              checkoutFlowProvider.overrideWith(
                () => SeededCheckoutFlow(_checkoutFlow()),
              ),
            ],
            child: appWithRealRouter(onRouter: (GoRouter r) => router = r),
          ),
        );
        await tester.pump();
        container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );

        router.go(AppRoutes.homePath);
        await tester.pumpAndSettle();
        router.push(AppRoutes.checkoutPath);
        // Not `pumpAndSettle()` — `/checkout` starts a `Timer.periodic`
        // the moment it mounts, which never settles. The extra
        // `pump(Duration(...))` lets the push's page-transition run its
        // course instead of leaving `CheckoutScreen` mid-transition.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(CheckoutScreen), findsOneWidget);
        expect(container.read(checkoutFlowProvider), isNotNull);
        return router;
      }

      testWidgets('a refresh does NOT end the flow', (tester) async {
        final GoRouter router = await pumpOnCheckout(tester);

        router.refresh();
        await tester.pump();

        expect(
          container.read(checkoutFlowProvider),
          isNotNull,
          reason: 'refresh cleared the flow the user is still standing in',
        );
        expect(find.byType(CheckoutScreen), findsOneWidget);
      });

      testWidgets(
        'backing out before finishing ends the flow (the "abandon" case)',
        (tester) async {
          final GoRouter router = await pumpOnCheckout(tester);

          router.pop();
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));

          expect(find.byType(CheckoutScreen), findsNothing);
          expect(
            container.read(checkoutFlowProvider),
            isNull,
            reason: 'the flow outlived the screen it belongs to',
          );
        },
      );

      testWidgets(
        'leaving by "กลับหน้าแรก" after the order is created ends the flow '
        'too (the "finished" case)',
        (tester) async {
          final GoRouter router = await pumpOnCheckout(tester);
          container.read(checkoutViewModelProvider.notifier).state =
              CheckoutOrderCreated(_order());
          await tester.pump();
          expect(find.byType(CheckoutOrderCreatedView), findsOneWidget);

          router.go(AppRoutes.homePath);
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));

          expect(find.byType(CheckoutScreen), findsNothing);
          expect(container.read(checkoutFlowProvider), isNull);
        },
      );

      testWidgets('leaving and coming back with a new reservation reaches '
          'CheckoutReady with a blank form — nothing from the earlier visit '
          'survives', (tester) async {
        final GoRouter router = await pumpOnCheckout(tester);

        router.pop();
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(container.read(checkoutFlowProvider), isNull);

        container.read(checkoutFlowProvider.notifier).start(_checkoutFlow());
        router.push(AppRoutes.checkoutPath);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));

        expect(find.byType(CheckoutScreen), findsOneWidget);
        expect(container.read(checkoutViewModelProvider), isA<CheckoutReady>());
        expect(
          tester
              .widgetList<TextFormField>(find.byType(TextFormField))
              .every((w) => (w.controller?.text ?? '').isEmpty),
          isTrue,
          reason: 'a field carried text over from the earlier visit',
        );
      });
    },
  );
}
