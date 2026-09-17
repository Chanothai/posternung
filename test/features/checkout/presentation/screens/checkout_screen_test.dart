import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/order_exception.dart';
import 'package:posternung/core/router/app_routes.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/core/theme/app_colors.dart';
import 'package:posternung/core/theme/app_theme.dart';
import 'package:posternung/features/checkout/presentation/checkout_flow_observer.dart';
import 'package:posternung/features/checkout/domain/entities/order.dart';
import 'package:posternung/features/checkout/domain/entities/order_status.dart';
import 'package:posternung/features/checkout/domain/entities/reservation.dart';
import 'package:posternung/features/checkout/domain/entities/shipping_address.dart';
import 'package:posternung/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:posternung/features/checkout/presentation/providers/checkout_flow_provider.dart';
import 'package:posternung/features/checkout/presentation/providers/checkout_providers.dart';
import 'package:posternung/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:posternung/features/poster/domain/entities/poster_detail.dart';
import 'package:posternung/features/poster/domain/entities/poster_status.dart';

import '../../../../support/backend_envelope_fixture.dart';
import '../../../../support/checkout_flow_harness.dart';
import '../../../../support/manual_stopwatch.dart';

class MockCheckoutRepository extends Mock implements CheckoutRepository {}

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

CheckoutFlowState _flow({Duration span = const Duration(minutes: 30)}) {
  final createdAt = DateTime.utc(2026, 9, 16, 15, 30);
  return CheckoutFlowState(
    reservation: Reservation(
      id: 'r1',
      posterId: 'p1',
      createdAt: createdAt,
      expiresAt: createdAt.add(span),
    ),
    posterSnapshot: _poster(),
    stopwatch: ManualStopwatch(),
  );
}

/// Self-contained harness for `CheckoutScreen` alone — not the real route
/// table (that wiring is covered separately in `app_router_test.dart`, B1's
/// own scope). `/home` and `/privacy` are stand-in destinations so a tap on
/// "กลับหน้าแรก"/the privacy link can be asserted by the resulting location
/// without pulling in `AuthGate`/`HomeScreen`'s own dependencies.
Widget _harness({
  required CheckoutRepository repository,
  CheckoutFlowState? flow,
  void Function(GoRouter router)? onRouter,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => CheckoutScreen(posterSnapshot: _poster()),
      ),
      GoRoute(
        path: AppRoutes.homePath,
        builder: (_, _) => const Text('HOME_STUB'),
      ),
      GoRoute(
        path: AppRoutes.privacyPath,
        builder: (_, _) => const Text('PRIVACY_STUB'),
      ),
    ],
  );
  onRouter?.call(router);
  return ProviderScope(
    overrides: [
      checkoutRepositoryProvider.overrideWithValue(repository),
      checkoutFlowProvider.overrideWith(
        () => SeededCheckoutFlow(flow ?? _flow()),
      ),
    ],
    // `AppTheme.dark()` — the theme `main.dart` installs. Not optional here:
    // since SCR-07 B9 the form's fill/borders/padding and the CTA's shape
    // come from the theme, so a harness without it would render the
    // `ThemeData` default and the 422 highlight below (which points at the
    // theme's own `errorBorder`) would silently never paint.
    child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
  );
}

/// The screen **pushed** on top of an origin route, wired with the real
/// [CheckoutFlowObserver] — for the B9-1 back tests, whose subject is
/// leaving `/checkout` the way a user does (header button, system back) and
/// what that does to `checkoutFlowProvider`.
///
/// The router is built inside a `Provider` because the observer needs a
/// `Ref` — the same shape `routerProvider` uses in `app_router.dart`. The
/// route is registered under [AppRoutes.checkoutName], which is what the
/// observer's `didPop` keys on; a nameless route would leave the flow
/// untouched and the assertion on `null` would be testing nothing.
final Provider<GoRouter> _pushedRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('ORIGIN_STUB')),
      GoRoute(
        path: AppRoutes.checkoutPath,
        name: AppRoutes.checkoutName,
        builder: (_, _) => CheckoutScreen(posterSnapshot: _poster()),
      ),
    ],
    observers: [CheckoutFlowObserver(ref)],
  );
  ref.onDispose(router.dispose);
  return router;
});

Widget _pushedHarness({
  required CheckoutRepository repository,
  required void Function(GoRouter router) onRouter,
}) {
  return ProviderScope(
    overrides: [
      checkoutRepositoryProvider.overrideWithValue(repository),
      checkoutFlowProvider.overrideWith(() => SeededCheckoutFlow(_flow())),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final router = ref.watch(_pushedRouterProvider);
        onRouter(router);
        return MaterialApp.router(theme: AppTheme.dark(), routerConfig: router);
      },
    ),
  );
}

void main() {
  late MockCheckoutRepository repository;

  setUpAll(() {
    registerFallbackValue(
      const ShippingAddress(
        recipientName: 'x',
        recipientPhone: 'x',
        addressLine: 'x',
        province: 'x',
        postalCode: 'x',
      ),
    );
  });

  setUp(() {
    repository = MockCheckoutRepository();
  });

  Future<void> fillValidForm(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'สมชาย ใจดี'); // recipient name
    await tester.enterText(fields.at(1), '0812345678'); // recipient phone
    await tester.enterText(fields.at(2), '123 ถนนสุขุมวิท'); // address line
    // sub_district (3), district (4) — left blank, optional
    await tester.enterText(fields.at(5), 'กรุงเทพมหานคร'); // province
    await tester.enterText(fields.at(6), '10110'); // postal code
  }

  // Since SCR-07 B9 the submit button sits in the sticky bottom bar
  // (`Scaffold.bottomNavigationBar`), not inside the scroll view — it is
  // always on screen, so no `ensureVisible` is needed (or possible: there is
  // no `Scrollable` above it).
  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.tap(find.text('ยืนยันคำสั่งซื้อ'));
  }

  /// Scrolls [finder] to the **middle** of the viewport. Since B9 the body
  /// extends under the blurred sticky bar (`Scaffold.extendBody`), so
  /// `tester.ensureVisible` — which scrolls the minimum, leaving the target
  /// hugging the viewport's bottom edge — parks it exactly under the bar,
  /// where a tap lands on the bar instead. Centering is what a finger
  /// scrolling past the bar ends up doing anyway.
  Future<void> scrollToCenter(WidgetTester tester, Finder finder) async {
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pump();
  }

  testWidgets('renders the summary, the AC-3 shipping note verbatim, and '
      'the countdown', (tester) async {
    await tester.pumpWidget(_harness(repository: repository));
    await tester.pump();

    expect(find.text('Blade Runner'), findsOneWidget);
    // F3 — BUSINESS_RULES.md BR-B3: the product price must be on this
    // screen. `formatThbPrice('450.00')` — matches the fixture's price
    // exactly, not just "some text is there".
    expect(find.text('฿450.00'), findsOneWidget);
    expect(
      find.text(
        'ค่าส่งรวมในราคาแล้ว โปสเตอร์ส่งในท่อแข็งหรือแฟ้มแข็งแบบแบน '
        'ตามสภาพและขนาดของใบนั้น',
      ),
      findsOneWidget,
    );
    expect(find.text('30:00'), findsOneWidget);
  });

  testWidgets(
    'F11 — tapping the privacy link navigates to /privacy, and the address '
    'form has no checkbox anywhere on it (no consent checkbox exists — the '
    'link itself is the only privacy affordance)',
    (tester) async {
      late GoRouter router;
      await tester.pumpWidget(
        _harness(repository: repository, onRouter: (r) => router = r),
      );
      await tester.pump();

      expect(find.byType(Checkbox), findsNothing);

      // The link sits below the fold on the default 800x600 surface — it
      // has to be scrolled into the clear (see `scrollToCenter`), or the tap
      // lands on whatever actually occupies that offset instead.
      final privacyLink = find.text('อ่านประกาศเกี่ยวกับความเป็นส่วนตัว');
      await scrollToCenter(tester, privacyLink);

      // `pump()`, not `pumpAndSettle()` — the privacy link *pushes*
      // `/privacy` on top of `/`, so `CheckoutScreen` (and its live
      // `reservationCountdownProvider` `Timer.periodic`, per this file's
      // own `_harness` doc trail) stays mounted underneath and never settles
      // (same trap `app_router_test.dart`'s `pumpAt` doc comment names).
      await tester.tap(privacyLink);
      await tester.pump();
      await tester.pump();

      expect(router.state.uri.toString(), AppRoutes.privacyPath);
      expect(find.text('PRIVACY_STUB'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping submit with required fields empty does NOT call createOrder '
    '(client-side validation runs first)',
    (tester) async {
      await tester.pumpWidget(_harness(repository: repository));
      await tester.pump();

      await tapSubmit(tester);
      await tester.pump();

      verifyNever(
        () => repository.createOrder(
          reservationId: any(named: 'reservationId'),
          shippingAddress: any(named: 'shippingAddress'),
        ),
      );
      expect(find.text('กรุณากรอกข้อมูลนี้ให้ครบ'), findsWidgets);
    },
  );

  group('CheckoutOrderCreated', () {
    testWidgets(
      'a successful submit shows order_no + "รอชำระเงิน" and exactly two '
      'tappable controls — the view\'s "กลับหน้าแรก" and the header back '
      'button (B9-1: back is always available) — closed-world '
      '(test-quality §4)',
      (tester) async {
        when(
          () => repository.createOrder(
            reservationId: any(named: 'reservationId'),
            shippingAddress: any(named: 'shippingAddress'),
          ),
        ).thenAnswer(
          (_) async => Order(
            id: 'o1',
            orderNo: 'PN-260916-0001',
            posterId: 'p1',
            status: OrderStatus.awaitingPayment,
            itemPrice: '450.00',
            shippingFee: '0.00',
            totalAmount: '450.00',
            itemTitle: 'Blade Runner',
            createdAt: DateTime.utc(2026, 9, 16),
          ),
        );

        await tester.pumpWidget(_harness(repository: repository));
        await tester.pump();
        await fillValidForm(tester);
        await tapSubmit(tester);
        await tester.pump();
        await tester.pump();

        expect(find.text('บันทึกคำสั่งซื้อแล้ว'), findsOneWidget);
        expect(find.textContaining('PN-260916-0001'), findsOneWidget);
        expect(find.text('รอชำระเงิน'), findsOneWidget);

        // Closed-world: no "สำเร็จ" anywhere on this view.
        expect(find.textContaining('สำเร็จ'), findsNothing);
        expect(find.textContaining('ทางร้านจะติดต่อ'), findsNothing);

        // Exactly two tappable controls on the whole screen at this point,
        // and each is accounted for by name: the view's own CTA and the
        // header's back button (`GlassCircleButton` is an `IconButton`).
        // Anything else — a second CTA, a "pay now", a share — fails here.
        final tappable = <Finder>[
          find.byWidgetPredicate(
            (w) => w is ElevatedButton && w.onPressed != null,
          ),
          find.byWidgetPredicate(
            (w) => w is OutlinedButton && w.onPressed != null,
          ),
          find.byWidgetPredicate((w) => w is TextButton && w.onPressed != null),
          find.byWidgetPredicate((w) => w is IconButton && w.onPressed != null),
        ];
        final total = tappable.fold<int>(
          0,
          (sum, f) => sum + tester.widgetList(f).length,
        );
        expect(total, 2);
        expect(
          find.ancestor(
            of: find.text('กลับหน้าแรก'),
            matching: find.byType(ElevatedButton),
          ),
          findsOneWidget,
        );
        expect(
          find.byTooltip(AppStrings.checkoutBackButtonTooltip),
          findsOneWidget,
        );

        await tester.tap(find.text('กลับหน้าแรก'));
        await tester.pumpAndSettle();
        expect(find.text('HOME_STUB'), findsOneWidget);
      },
    );
  });

  group('CheckoutReservationLost', () {
    testWidgets('409 RESERVATION_NOT_ACTIVE with expired_at shows the '
        '"หมดเวลาแล้ว" message and a way back to the poster', (tester) async {
      when(
        () => repository.createOrder(
          reservationId: any(named: 'reservationId'),
          shippingAddress: any(named: 'shippingAddress'),
        ),
      ).thenThrow(
        OrderException.fromEnvelope(
          backendEnvelopeFixture(
            code: 'RESERVATION_NOT_ACTIVE',
            details: [
              {'field': 'expired_at', 'message': '2026-09-16T09:00:00Z'},
            ],
          ),
        ),
      );

      await tester.pumpWidget(_harness(repository: repository));
      await tester.pump();
      await fillValidForm(tester);
      await tapSubmit(tester);
      await tester.pump();
      await tester.pump();

      expect(
        find.text('การจองหมดเวลาแล้ว ถ้ายังว่างกดซื้อเลยใหม่ได้'),
        findsOneWidget,
      );
      expect(find.text('กลับไปหน้าโปสเตอร์'), findsOneWidget);
    });
  });

  group('CheckoutFailed — 422', () {
    testWidgets('renders the fixed Thai copy, never the English validator '
        'prose, and leaves the form on screen', (tester) async {
      when(
        () => repository.createOrder(
          reservationId: any(named: 'reservationId'),
          shippingAddress: any(named: 'shippingAddress'),
        ),
      ).thenThrow(
        OrderException.fromEnvelope(
          backendEnvelopeFixture(
            code: 'VALIDATION_ERROR',
            message: 'ข้อมูลที่ส่งมาไม่ถูกต้อง',
            details: [
              {
                'field': 'shipping_address.postal_code',
                'message': 'ensure this value has at most 10 characters',
              },
            ],
          ),
        ),
      );

      await tester.pumpWidget(_harness(repository: repository));
      await tester.pump();
      await fillValidForm(tester);
      await tapSubmit(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text('กรุณาตรวจสอบข้อมูลที่อยู่อีกครั้ง'), findsOneWidget);
      expect(find.textContaining('ensure this value'), findsNothing);
      // Form is still there — a retry is possible without re-navigating.
      expect(find.byType(TextFormField), findsNWidgets(7));

      // F5 — the backend reported `shipping_address.postal_code` (the
      // nested form field), which `OrderException.validationFields` must
      // strip down to `postal_code` for `CheckoutAddressForm` to actually
      // highlight the right box. Field order in `fillValidForm`/the form
      // itself: 0 name, 1 phone, 2 address line, 3 sub-district, 4
      // district, 5 province, 6 postal code.
      // `TextFormField` doesn't expose `decoration` itself (it builds a
      // `TextField` internally via `FormField`'s builder), and under
      // Material 3 `InputDecorator` never falls back to the plain
      // `InputDecoration.border` — it resolves `enabledBorder` (unfocused,
      // no error, which is every field's state here) instead. Read that off
      // the rendered `InputDecorator`, one per `TextFormField` ancestor, in
      // the same on-screen order, so this asserts what Flutter actually
      // paints rather than a decoration field it may ignore.
      final formFields = find.byType(TextFormField);
      OutlineInputBorder borderOf(int index) =>
          tester
                  .widget<InputDecorator>(
                    find.descendant(
                      of: formFields.at(index),
                      matching: find.byType(InputDecorator),
                    ),
                  )
                  .decoration
                  .enabledBorder!
              as OutlineInputBorder;

      expect(borderOf(6).borderSide.color, AppColors.accentRed);
      // Negative control — every other field must stay un-highlighted, or
      // this would just be "some border turned red somewhere".
      for (final i in [0, 1, 2, 3, 4, 5]) {
        expect(
          borderOf(i).borderSide.color,
          isNot(AppColors.accentRed),
          reason: 'field $i lit up red for a 422 that only named postal_code',
        );
      }
    });
  });

  group('B9-1 — leaving /checkout (B8-3)', () {
    /// Lands on `/checkout` *pushed* over the origin route, the way the
    /// app reaches it from SCR-05 (`context.push`), with the real observer.
    Future<({GoRouter router, ProviderContainer container})> pumpPushed(
      WidgetTester tester,
    ) async {
      late GoRouter router;
      await tester.pumpWidget(
        _pushedHarness(repository: repository, onRouter: (r) => router = r),
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      router.push(AppRoutes.checkoutPath);
      // Not `pumpAndSettle()` — the screen's countdown `Timer.periodic`
      // never settles; let the push transition run out explicitly.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CheckoutScreen), findsOneWidget);
      expect(router.state.uri.toString(), AppRoutes.checkoutPath);
      expect(container.read(checkoutFlowProvider), isNotNull);
      return (router: router, container: container);
    }

    Future<void> expectLeft(
      WidgetTester tester,
      ({GoRouter router, ProviderContainer container}) app,
    ) async {
      // The observer clears the flow one event-loop turn after `didPop`.
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(CheckoutScreen), findsNothing);
      expect(find.text('ORIGIN_STUB'), findsOneWidget);
      expect(app.router.state.uri.toString(), '/');
      expect(
        app.container.read(checkoutFlowProvider),
        isNull,
        reason: 'CheckoutFlowObserver did not clear the flow on this pop',
      );
    }

    testWidgets('(a) the header back button pops the route and the flow is '
        'cleared by the observer', (tester) async {
      final app = await pumpPushed(tester);

      final back = find.byTooltip(AppStrings.checkoutBackButtonTooltip);
      expect(back, findsOneWidget);
      await tester.tap(back);

      await expectLeft(tester, app);
    });

    testWidgets('(b) system back — `handlePopRoute()`, the same path '
        'KEYCODE_BACK / the back gesture take — pops the route too', (
      tester,
    ) async {
      final app = await pumpPushed(tester);

      await tester.binding.handlePopRoute();

      expect(tester.takeException(), isNull);
      await expectLeft(tester, app);
    });

    testWidgets('(c) the route is genuinely poppable: `ModalRoute.'
        'popDisposition` reads `pop` and the one `PopScope` around the '
        'Scaffold has `canPop: true` — no confirm dialog stands in the way', (
      tester,
    ) async {
      await pumpPushed(tester);

      // Read off the live route, not the widget: this is the value the
      // navigator actually consults on a back press.
      final route = ModalRoute.of(tester.element(find.byType(Scaffold)))!;
      expect(route.popDisposition, RoutePopDisposition.pop);

      // `find.byType(PopScope)` would look for `PopScope<dynamic>` and miss
      // the `PopScope<Object?>` an untyped constructor call produces.
      final popScopes = find.ancestor(
        of: find.byType(Scaffold),
        matching: find.byWidgetPredicate((w) => w is PopScope),
      );
      expect(popScopes, findsOneWidget);
      expect((tester.widget(popScopes) as PopScope).canPop, isTrue);
      // Negative: nothing intercepts the pop to show a dialog.
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('AC-B9-3 — the form renders the theme\'s input tokens', () {
    testWidgets('every field paints `inputFill` and a `inputBorder` outline '
        '— read off what is rendered, not off `InputDecoration.border`', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(repository: repository));
      await tester.pump();

      final formFields = find.byType(TextFormField);
      expect(formFields, findsNWidgets(7));

      for (int i = 0; i < 7; i++) {
        // 1. The decoration `TextField` hands to `InputDecorator` *after*
        //    `applyDefaults(theme)` — the theme's values are already merged
        //    in here, and `enabledBorder` is the one Material 3 resolves for
        //    an unfocused, error-free field (SCR-02 N-1: `border:` is not).
        final decorator = tester.widget<InputDecorator>(
          find.descendant(
            of: formFields.at(i),
            matching: find.byType(InputDecorator),
          ),
        );
        final decoration = decorator.decoration;
        expect(decoration.filled, isTrue, reason: 'field $i is not filled');
        expect(
          decoration.fillColor,
          AppColors.inputFill,
          reason: 'field $i fill is not the theme token',
        );
        final enabled = decoration.enabledBorder;
        expect(enabled, isA<OutlineInputBorder>(), reason: 'field $i');
        expect(
          (enabled! as OutlineInputBorder).borderSide.color,
          AppColors.inputBorder,
          reason: 'field $i resting border is not the theme token',
        );
        // Negative: the pre-B9 white fill / grey border must be gone.
        expect(decoration.fillColor, isNot(AppColors.white));
        expect(enabled.borderSide.color, isNot(AppColors.borderMuted));

        // 2. What `InputDecorator` actually painted: its private
        //    `_BorderContainer` carries the resolved `border` and
        //    `fillColor` that `CustomPaint`s the box. Reached by type name
        //    + dynamic member access because the class is private to
        //    Flutter — if Flutter renames it this fails loudly (the
        //    `findsOneWidget` below), never silently.
        final painted = find.descendant(
          of: formFields.at(i),
          matching: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_BorderContainer',
          ),
        );
        expect(painted, findsOneWidget, reason: 'field $i');
        final dynamic container = tester.widget(painted);
        expect(container.fillColor, AppColors.inputFill, reason: 'field $i');
        expect(
          (container.border as OutlineInputBorder).borderSide.color,
          AppColors.inputBorder,
          reason: 'field $i',
        );
      }
    });
  });
}
