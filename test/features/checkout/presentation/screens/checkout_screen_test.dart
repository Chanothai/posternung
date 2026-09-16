import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/order_exception.dart';
import 'package:posternung/core/router/app_routes.dart';
import 'package:posternung/core/theme/app_colors.dart';
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
    child: MaterialApp.router(routerConfig: router),
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

  // The form is taller than the default 800x600 test surface, so the submit
  // button starts out below the fold — `ensureVisible` scrolls the
  // `CustomScrollView` until it's actually hit-testable, the same thing a
  // real finger would have to do first.
  Future<void> tapSubmit(WidgetTester tester) async {
    final submit = find.text('ยืนยันคำสั่งซื้อ');
    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.tap(submit);
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

      // The link sits below the fold on the default 800x600 surface — same
      // `ensureVisible` step `tapSubmit` above needs, or the tap lands on
      // whatever actually occupies that offset instead.
      final privacyLink = find.text('อ่านประกาศเกี่ยวกับความเป็นส่วนตัว');
      await tester.ensureVisible(privacyLink);
      await tester.pump();

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
      'a successful submit shows order_no + "รอชำระเงิน" and exactly one '
      'tappable control ("กลับหน้าแรก") — closed-world (test-quality §4)',
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

        // Exactly one tappable control on the whole screen at this point.
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
        expect(total, 1);

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
}
