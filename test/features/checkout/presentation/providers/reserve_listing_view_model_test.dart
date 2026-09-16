import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/order_exception.dart';
import 'package:posternung/features/checkout/domain/entities/reservation.dart';
import 'package:posternung/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:posternung/features/checkout/presentation/providers/checkout_flow_provider.dart';
import 'package:posternung/features/checkout/presentation/providers/checkout_providers.dart';
import 'package:posternung/features/checkout/presentation/providers/reserve_listing_view_model.dart';
import 'package:posternung/features/checkout/presentation/state/reserve_listing_state.dart';
import 'package:posternung/features/poster/domain/entities/poster_detail.dart';
import 'package:posternung/features/poster/domain/entities/poster_status.dart';

class MockCheckoutRepository extends Mock implements CheckoutRepository {}

PosterDetail _poster({PosterStatus status = PosterStatus.available}) =>
    PosterDetail(
      id: 'p1',
      title: 'Blade Runner',
      price: '450.00',
      status: status,
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
      createdAt: DateTime.utc(2024),
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

Reservation _reservation() => Reservation(
  id: 'r1',
  posterId: 'p1',
  createdAt: DateTime.utc(2026, 9, 16, 15, 30),
  expiresAt: DateTime.utc(2026, 9, 16, 16, 30),
);

void main() {
  late MockCheckoutRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockCheckoutRepository();
    container = ProviderContainer(
      overrides: [checkoutRepositoryProvider.overrideWithValue(repository)],
    );
    // F6 — reserveListingViewModelProvider is now `.autoDispose.family`. A
    // bare `container.read()` with no listener gets disposed again on the
    // next microtask; every test below awaits (or completes a `Completer`)
    // between reading `.notifier` and reading the state back, so without
    // this keep-alive the provider would silently reset to a fresh
    // `ReserveListingIdle` mid-test instead of reflecting what `reserve()`
    // actually did.
    addTearDown(
      container.listen(reserveListingViewModelProvider('p1'), (_, _) {}).close,
    );
  });

  tearDown(() => container.dispose());

  test('starts idle', () {
    expect(
      container.read(reserveListingViewModelProvider('p1')),
      isA<ReserveListingIdle>(),
    );
  });

  group('reserve()', () {
    test(
      'calls repository.reserveListing with exactly this posterId — even '
      'for a `reserved` poster (SCR-07 AC-15: never gated on `status`)',
      () async {
        when(
          () => repository.reserveListing('p1'),
        ).thenAnswer((_) async => _reservation());

        await container
            .read(reserveListingViewModelProvider('p1').notifier)
            .reserve(_poster(status: PosterStatus.reserved));

        verify(() => repository.reserveListing('p1')).called(1);
      },
    );

    test('flips to Submitting while the call is in flight, and back to Idle '
        'on success', () async {
      final completer = Completer<Reservation>();
      when(
        () => repository.reserveListing('p1'),
      ).thenAnswer((_) => completer.future);

      final future = container
          .read(reserveListingViewModelProvider('p1').notifier)
          .reserve(_poster());
      expect(
        container.read(reserveListingViewModelProvider('p1')),
        isA<ReserveListingSubmitting>(),
      );

      completer.complete(_reservation());
      await future;

      expect(
        container.read(reserveListingViewModelProvider('p1')),
        isA<ReserveListingIdle>(),
      );
    });

    test(
      '201 starts checkoutFlowProvider with that reservation and this '
      'exact poster snapshot, and returns the reservation to the caller',
      () async {
        final reservation = _reservation();
        when(
          () => repository.reserveListing('p1'),
        ).thenAnswer((_) async => reservation);
        final poster = _poster();

        final result = await container
            .read(reserveListingViewModelProvider('p1').notifier)
            .reserve(poster);

        expect(result, same(reservation));
        final flow = container.read(checkoutFlowProvider);
        expect(flow, isNotNull);
        expect(flow!.reservation, same(reservation));
        expect(flow.posterSnapshot, same(poster));
      },
    );

    test('a failure sets ReserveListingFailed with that exception, returns '
        'null, and never touches checkoutFlowProvider', () async {
      when(
        () => repository.reserveListing('p1'),
      ).thenThrow(const OrderException(code: 'POSTER_NOT_AVAILABLE'));

      final result = await container
          .read(reserveListingViewModelProvider('p1').notifier)
          .reserve(_poster());

      expect(result, isNull);
      expect(
        container.read(reserveListingViewModelProvider('p1')),
        isA<ReserveListingFailed>().having(
          (s) => s.exception.code,
          'exception.code',
          'POSTER_NOT_AVAILABLE',
        ),
      );
      expect(container.read(checkoutFlowProvider), isNull);
    });

    test('a retry after a failure can still reach success (state is not '
        'stuck once Failed)', () async {
      when(
        () => repository.reserveListing('p1'),
      ).thenThrow(const OrderException(code: 'network_error'));
      await container
          .read(reserveListingViewModelProvider('p1').notifier)
          .reserve(_poster());
      expect(
        container.read(reserveListingViewModelProvider('p1')),
        isA<ReserveListingFailed>(),
      );

      when(
        () => repository.reserveListing('p1'),
      ).thenAnswer((_) async => _reservation());
      final result = await container
          .read(reserveListingViewModelProvider('p1').notifier)
          .reserve(_poster());

      expect(result, isNotNull);
      expect(
        container.read(reserveListingViewModelProvider('p1')),
        isA<ReserveListingIdle>(),
      );
    });
  });
}
