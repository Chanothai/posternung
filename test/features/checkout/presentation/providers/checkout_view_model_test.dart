import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/order_exception.dart';
import 'package:posternung/features/checkout/domain/entities/order.dart';
import 'package:posternung/features/checkout/domain/entities/order_status.dart';
import 'package:posternung/features/checkout/domain/entities/reservation.dart';
import 'package:posternung/features/checkout/domain/entities/shipping_address.dart';
import 'package:posternung/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:posternung/features/checkout/presentation/providers/checkout_flow_provider.dart';
import 'package:posternung/features/checkout/presentation/providers/checkout_providers.dart';
import 'package:posternung/features/checkout/presentation/providers/checkout_view_model.dart';
import 'package:posternung/features/checkout/presentation/state/checkout_state.dart';
import 'package:posternung/features/poster/domain/entities/poster_detail.dart';
import 'package:posternung/features/poster/domain/entities/poster_status.dart';

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

const _address = ShippingAddress(
  recipientName: 'สมชาย ใจดี',
  recipientPhone: '0812345678',
  addressLine: '123 ถนนสุขุมวิท',
  province: 'กรุงเทพมหานคร',
  postalCode: '10110',
);

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
  late MockCheckoutRepository repository;
  late ManualStopwatch stopwatch;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(_address);
  });

  setUp(() {
    repository = MockCheckoutRepository();
    stopwatch = ManualStopwatch();
    container = ProviderContainer(
      overrides: [checkoutRepositoryProvider.overrideWithValue(repository)],
    );
    final createdAt = DateTime.utc(2026, 9, 16, 15, 30);
    container
        .read(checkoutFlowProvider.notifier)
        .start(
          CheckoutFlowState(
            reservation: Reservation(
              id: 'r1',
              posterId: 'p1',
              createdAt: createdAt,
              expiresAt: createdAt.add(const Duration(seconds: 3)),
            ),
            posterSnapshot: _poster(),
            stopwatch: stopwatch,
          ),
        );
  });

  tearDown(() => container.dispose());

  // F1 — checkoutViewModelProvider is now `.autoDispose`. A bare
  // `container.read()` with no listener attached gets torn down again on
  // the next microtask — every `submit()` test below awaits at least once
  // between reading `.notifier` and reading the resulting state back, so
  // each needs its own keep-alive.
  //
  // 🔴 This must NOT live in `setUp()`: `setUp()` runs outside each
  // `testWidgets`'s `FakeAsync` zone, so a listener created there would
  // build `CheckoutViewModel` (and, transitively, `reservationCountdown
  // Provider`'s `Timer.periodic`) against the *real* clock — completely
  // deaf to `tester.pump(Duration(...))` in the "countdown reaching zero"
  // group below. Confirmed by running it that way first: every countdown
  // test in this file went from green to "state stays CheckoutReady",
  // because the real timer never got a chance to fire during a fake-time
  // pump. Each test that needs the keep-alive creates it itself, inside its
  // own body, same as the "countdown reaching zero" group already does.
  void keepViewModelAlive() {
    addTearDown(container.listen(checkoutViewModelProvider, (_, _) {}).close);
  }

  test('starts as CheckoutReady', () {
    expect(container.read(checkoutViewModelProvider), isA<CheckoutReady>());
  });

  group('submit()', () {
    test('201 → CheckoutOrderCreated', () async {
      keepViewModelAlive();
      when(
        () => repository.createOrder(
          reservationId: any(named: 'reservationId'),
          shippingAddress: any(named: 'shippingAddress'),
        ),
      ).thenAnswer((_) async => _order());

      await container.read(checkoutViewModelProvider.notifier).submit(_address);

      expect(
        container.read(checkoutViewModelProvider),
        isA<CheckoutOrderCreated>().having((s) => s.order.id, 'order.id', 'o1'),
      );
    });

    test(
      '409 RESERVATION_NOT_ACTIVE → CheckoutReservationLost (AC-4)',
      () async {
        keepViewModelAlive();
        when(
          () => repository.createOrder(
            reservationId: any(named: 'reservationId'),
            shippingAddress: any(named: 'shippingAddress'),
          ),
        ).thenThrow(const OrderException(code: 'RESERVATION_NOT_ACTIVE'));

        await container
            .read(checkoutViewModelProvider.notifier)
            .submit(_address);

        expect(
          container.read(checkoutViewModelProvider),
          isA<CheckoutReservationLost>(),
        );
      },
    );

    test('404 RESERVATION_NOT_FOUND → CheckoutReservationLost', () async {
      keepViewModelAlive();
      when(
        () => repository.createOrder(
          reservationId: any(named: 'reservationId'),
          shippingAddress: any(named: 'shippingAddress'),
        ),
      ).thenThrow(const OrderException(code: 'RESERVATION_NOT_FOUND'));

      await container.read(checkoutViewModelProvider.notifier).submit(_address);

      expect(
        container.read(checkoutViewModelProvider),
        isA<CheckoutReservationLost>(),
      );
    });

    test('409 POSTER_NOT_AVAILABLE → CheckoutReservationLost', () async {
      keepViewModelAlive();
      when(
        () => repository.createOrder(
          reservationId: any(named: 'reservationId'),
          shippingAddress: any(named: 'shippingAddress'),
        ),
      ).thenThrow(const OrderException(code: 'POSTER_NOT_AVAILABLE'));

      await container.read(checkoutViewModelProvider.notifier).submit(_address);

      expect(
        container.read(checkoutViewModelProvider),
        isA<CheckoutReservationLost>(),
      );
    });

    test(
      '422 VALIDATION_ERROR → CheckoutFailed, form stays retryable',
      () async {
        keepViewModelAlive();
        when(
          () => repository.createOrder(
            reservationId: any(named: 'reservationId'),
            shippingAddress: any(named: 'shippingAddress'),
          ),
        ).thenThrow(const OrderException(code: 'VALIDATION_ERROR'));

        await container
            .read(checkoutViewModelProvider.notifier)
            .submit(_address);

        expect(
          container.read(checkoutViewModelProvider),
          isA<CheckoutFailed>(),
        );
      },
    );

    test('network_error → CheckoutFailed', () async {
      keepViewModelAlive();
      when(
        () => repository.createOrder(
          reservationId: any(named: 'reservationId'),
          shippingAddress: any(named: 'shippingAddress'),
        ),
      ).thenThrow(const OrderException(code: 'network_error'));

      await container.read(checkoutViewModelProvider.notifier).submit(_address);

      expect(container.read(checkoutViewModelProvider), isA<CheckoutFailed>());
    });

    test(
      'a retry from CheckoutFailed can still reach CheckoutOrderCreated',
      () async {
        keepViewModelAlive();
        when(
          () => repository.createOrder(
            reservationId: any(named: 'reservationId'),
            shippingAddress: any(named: 'shippingAddress'),
          ),
        ).thenThrow(const OrderException(code: 'network_error'));
        await container
            .read(checkoutViewModelProvider.notifier)
            .submit(_address);
        expect(
          container.read(checkoutViewModelProvider),
          isA<CheckoutFailed>(),
        );

        when(
          () => repository.createOrder(
            reservationId: any(named: 'reservationId'),
            shippingAddress: any(named: 'shippingAddress'),
          ),
        ).thenAnswer((_) async => _order());
        await container
            .read(checkoutViewModelProvider.notifier)
            .submit(_address);

        expect(
          container.read(checkoutViewModelProvider),
          isA<CheckoutOrderCreated>(),
        );
      },
    );
  });

  group('countdown reaching zero (AC-11)', () {
    testWidgets(
      'CheckoutReady + countdown hits zero → CheckoutReservationLost',
      (tester) async {
        // Keep the viewmodel (autoDispose) alive for the life of this test
        // — its build() is what subscribes to the countdown provider, and a
        // bare `read()` with no listener would let Riverpod dispose it
        // again on the next microtask, before the timer ever fires.
        final sub = container.listen(checkoutViewModelProvider, (_, _) {});
        addTearDown(sub.close);
        expect(container.read(checkoutViewModelProvider), isA<CheckoutReady>());

        stopwatch.manualElapsed = const Duration(seconds: 3);
        await tester.pump(const Duration(seconds: 3));

        expect(
          container.read(checkoutViewModelProvider),
          isA<CheckoutReservationLost>(),
        );
      },
    );

    testWidgets(
      'CheckoutSubmitting + countdown hits zero → state unchanged (backend '
      'decides an in-flight submit, not the client clock)',
      (tester) async {
        final sub = container.listen(checkoutViewModelProvider, (_, _) {});
        addTearDown(sub.close);
        // A submit that never resolves during this test.
        when(
          () => repository.createOrder(
            reservationId: any(named: 'reservationId'),
            shippingAddress: any(named: 'shippingAddress'),
          ),
        ).thenAnswer((_) => Completer<Order>().future);

        unawaited(
          container.read(checkoutViewModelProvider.notifier).submit(_address),
        );
        expect(
          container.read(checkoutViewModelProvider),
          isA<CheckoutSubmitting>(),
        );

        stopwatch.manualElapsed = const Duration(seconds: 3);
        await tester.pump(const Duration(seconds: 3));

        expect(
          container.read(checkoutViewModelProvider),
          isA<CheckoutSubmitting>(),
        );
      },
    );

    test('F1 guard — the countdown reaching zero because checkoutFlowProvider '
        'was cleared (not a genuine 60-minute expiry) leaves CheckoutReady '
        'alone. Plain test(), not testWidgets() — same reasoning as '
        'reservation_countdown_provider_test.dart\'s "clearing the flow '
        'rebuilds to Duration.zero" test: this only needs a synchronous read '
        'right after clear(), no fake time involved. 🔴 mutation-locking: '
        'deleting the `if (ref.read(checkoutFlowProvider) == null) return;` '
        'guard turns this red.', () {
      final sub = container.listen(checkoutViewModelProvider, (_, _) {});
      addTearDown(sub.close);
      expect(container.read(checkoutViewModelProvider), isA<CheckoutReady>());

      container.read(checkoutFlowProvider.notifier).clear();

      expect(container.read(checkoutViewModelProvider), isA<CheckoutReady>());
    });

    testWidgets('CheckoutOrderCreated + countdown hits zero → state unchanged '
        '(terminal state)', (tester) async {
      final sub = container.listen(checkoutViewModelProvider, (_, _) {});
      addTearDown(sub.close);
      when(
        () => repository.createOrder(
          reservationId: any(named: 'reservationId'),
          shippingAddress: any(named: 'shippingAddress'),
        ),
      ).thenAnswer((_) async => _order());
      await container.read(checkoutViewModelProvider.notifier).submit(_address);
      expect(
        container.read(checkoutViewModelProvider),
        isA<CheckoutOrderCreated>(),
      );

      stopwatch.manualElapsed = const Duration(seconds: 3);
      await tester.pump(const Duration(seconds: 3));

      expect(
        container.read(checkoutViewModelProvider),
        isA<CheckoutOrderCreated>(),
      );
    });
  });
}
