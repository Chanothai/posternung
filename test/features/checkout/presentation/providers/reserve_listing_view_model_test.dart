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

PosterDetail _poster({
  PosterStatus status = PosterStatus.available,
  String id = 'p1',
}) => PosterDetail(
  id: id,
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

Reservation _reservation({String id = 'r1', String posterId = 'p1'}) =>
    Reservation(
      id: id,
      posterId: posterId,
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

    test(
      'A5-D2 — the provider is disposed while reserve() is in flight (the '
      'buyer left the screen); when the 201 lands, checkoutFlowProvider '
      'still holds that reservation. 🔴 mutation-locking: moving '
      'flow.start() back behind `if (!ref.mounted) return` turns this red',
      () async {
        final completer = Completer<Reservation>();
        when(
          () => repository.reserveListing('p2'),
        ).thenAnswer((_) => completer.future);
        // A listener of our own (not the setUp keep-alive, which is for
        // `p1`) so the element can be dropped mid-call.
        final sub = container.listen(
          reserveListingViewModelProvider('p2'),
          (_, _) {},
        );
        final future = container
            .read(reserveListingViewModelProvider('p2').notifier)
            .reserve(_poster());
        expect(
          container.read(reserveListingViewModelProvider('p2')),
          isA<ReserveListingSubmitting>(),
        );

        // Last listener gone → `.autoDispose` disposes the element on the
        // next microtask. Two turns of the event loop so it has happened
        // before the response is completed below.
        sub.close();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        // Proof the element really was disposed: a fresh read is a fresh
        // build (`ReserveListingIdle`), not the `Submitting` we left.
        final probe = container.listen(
          reserveListingViewModelProvider('p2'),
          (_, _) {},
        );
        addTearDown(probe.close);
        expect(
          container.read(reserveListingViewModelProvider('p2')),
          isA<ReserveListingIdle>(),
          reason: 'the in-flight element was expected to be disposed here',
        );

        final reservation = Reservation(
          id: 'r-inflight',
          posterId: 'p2',
          createdAt: DateTime.utc(2026, 9, 16, 15, 30),
          expiresAt: DateTime.utc(2026, 9, 16, 16, 30),
        );
        completer.complete(reservation);
        await future;

        final flow = container.read(checkoutFlowProvider);
        expect(flow, isNotNull);
        expect(flow!.reservation.id, 'r-inflight');
      },
    );

    // code-critic 2026-09-17 F-High — the critic's probe, at VM level. Since
    // A5-D2 the response is handed to the flow even after dispose, which is
    // right for an *empty* flow (test above) and wrong for a flow another
    // poster already owns: `CheckoutViewModel.submit()` reads
    // `reservation.id` from the flow, so an overwrite here would `POST
    // /orders` for A while the screen shows B.
    group('cross-poster late response (F-High)', () {
      test("A's provider disposed mid-flight, B reserved and holding the flow, "
          "then A's late 201 lands: the flow is STILL B's, and A's reserve() "
          'returns null. 🔴 mutation-locking: replacing startIfOwnedBy with '
          'start() (overwrite always) turns this red', () async {
        final completerA = Completer<Reservation>();
        when(
          () => repository.reserveListing('pA'),
        ).thenAnswer((_) => completerA.future);
        final reservationB = _reservation(id: 'r-b', posterId: 'pB');
        when(
          () => repository.reserveListing('pB'),
        ).thenAnswer((_) async => reservationB);

        // A: tap, then leave (dispose) while in flight — same dance as
        // the A5-D2 test above.
        final subA = container.listen(
          reserveListingViewModelProvider('pA'),
          (_, _) {},
        );
        final futureA = container
            .read(reserveListingViewModelProvider('pA').notifier)
            .reserve(_poster(id: 'pA'));
        subA.close();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // B: tap, resolves at once → the flow is B's.
        final subB = container.listen(
          reserveListingViewModelProvider('pB'),
          (_, _) {},
        );
        addTearDown(subB.close);
        final posterB = _poster(id: 'pB');
        final resultB = await container
            .read(reserveListingViewModelProvider('pB').notifier)
            .reserve(posterB);
        expect(resultB, same(reservationB));
        final CheckoutFlowState? flowB = container.read(checkoutFlowProvider);
        expect(flowB!.reservation.id, 'r-b');

        // A's 201 finally lands.
        completerA.complete(_reservation(id: 'r-a', posterId: 'pA'));
        final resultA = await futureA;

        final CheckoutFlowState? after = container.read(checkoutFlowProvider);
        expect(
          after,
          same(flowB),
          reason: "A's late response overwrote B's open flow",
        );
        expect(after!.reservation.id, 'r-b');
        expect(after.reservation.id, isNot('r-a'));
        expect(after.posterSnapshot, same(posterB));
        // Dropped silently — the caller must not navigate on it.
        expect(resultA, isNull);
      });

      test("A's provider still mounted (A's screen sits under B's in the "
          "stack) when A's late 201 lands: the flow stays B's, A returns "
          'null and goes back to Idle — no failure notice, nothing to '
          'navigate on', () async {
        final completerA = Completer<Reservation>();
        when(
          () => repository.reserveListing('pA'),
        ).thenAnswer((_) => completerA.future);
        final reservationB = _reservation(id: 'r-b', posterId: 'pB');
        when(
          () => repository.reserveListing('pB'),
        ).thenAnswer((_) async => reservationB);

        final subA = container.listen(
          reserveListingViewModelProvider('pA'),
          (_, _) {},
        );
        addTearDown(subA.close); // kept alive for the whole test
        final futureA = container
            .read(reserveListingViewModelProvider('pA').notifier)
            .reserve(_poster(id: 'pA'));
        expect(
          container.read(reserveListingViewModelProvider('pA')),
          isA<ReserveListingSubmitting>(),
        );

        final subB = container.listen(
          reserveListingViewModelProvider('pB'),
          (_, _) {},
        );
        addTearDown(subB.close);
        await container
            .read(reserveListingViewModelProvider('pB').notifier)
            .reserve(_poster(id: 'pB'));
        final CheckoutFlowState? flowB = container.read(checkoutFlowProvider);
        expect(flowB!.reservation.id, 'r-b');

        completerA.complete(_reservation(id: 'r-a', posterId: 'pA'));
        final resultA = await futureA;

        expect(container.read(checkoutFlowProvider), same(flowB));
        expect(resultA, isNull);
        expect(
          container.read(reserveListingViewModelProvider('pA')),
          isA<ReserveListingIdle>(),
        );
        expect(
          container.read(reserveListingViewModelProvider('pA')),
          isNot(isA<ReserveListingFailed>()),
        );
      });

      test(
        'SAME poster, second tap → 200 replay (A5-D1): the flow IS '
        'rewritten with the replayed reservation and the fresh snapshot '
        '(positive counterpart — reconcile is not "first writer wins")',
        () async {
          final first = _reservation(id: 'r1');
          when(
            () => repository.reserveListing('p1'),
          ).thenAnswer((_) async => first);
          await container
              .read(reserveListingViewModelProvider('p1').notifier)
              .reserve(_poster());
          final CheckoutFlowState? before = container.read(
            checkoutFlowProvider,
          );
          expect(before!.reservation, same(first));

          // Server replays the same row (200) — same id, same poster.
          final replay = _reservation(id: 'r1');
          when(
            () => repository.reserveListing('p1'),
          ).thenAnswer((_) async => replay);
          final snapshot = _poster();
          final result = await container
              .read(reserveListingViewModelProvider('p1').notifier)
              .reserve(snapshot);

          expect(result, same(replay));
          final CheckoutFlowState? after = container.read(checkoutFlowProvider);
          expect(after, isNot(same(before)));
          expect(after!.reservation, same(replay));
          expect(after.posterSnapshot, same(snapshot));
        },
      );
    });

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
