import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/features/checkout/domain/entities/reservation.dart';
import 'package:posternung/features/checkout/presentation/providers/checkout_flow_provider.dart';
import 'package:posternung/features/poster/domain/entities/poster_detail.dart';
import 'package:posternung/features/poster/domain/entities/poster_status.dart';

PosterDetail _poster({String id = 'p1'}) => PosterDetail(
  id: id,
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

Reservation _reservation({String id = 'r1', String posterId = 'p1'}) =>
    Reservation(
      id: id,
      posterId: posterId,
      expiresAt: DateTime.utc(2026, 9, 16, 16, 30),
      createdAt: DateTime.utc(2026, 9, 16, 15, 30),
    );

void main() {
  test('build() starts with no flow open', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(checkoutFlowProvider), isNull);
  });

  test('start() replaces whatever was there wholesale', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final flowA = CheckoutFlowState(
      reservation: _reservation(),
      posterSnapshot: _poster(),
    );
    container.read(checkoutFlowProvider.notifier).start(flowA);
    expect(container.read(checkoutFlowProvider), same(flowA));

    final flowB = CheckoutFlowState(
      reservation: _reservation(),
      posterSnapshot: _poster(id: 'p2'),
    );
    container.read(checkoutFlowProvider.notifier).start(flowB);

    expect(container.read(checkoutFlowProvider), same(flowB));
    expect(container.read(checkoutFlowProvider), isNot(same(flowA)));
  });

  // code-critic 2026-09-17 F-High — the reserve path's single gate. It
  // reconciles rather than overwrites: a late response for poster A must
  // not replace an open flow for poster B.
  group('startIfOwnedBy()', () {
    test('no flow open → writes and returns true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final flowA = CheckoutFlowState(
        reservation: _reservation(),
        posterSnapshot: _poster(),
      );

      final accepted = container
          .read(checkoutFlowProvider.notifier)
          .startIfOwnedBy('p1', flowA);

      expect(accepted, isTrue);
      expect(container.read(checkoutFlowProvider), same(flowA));
    });

    test('the open flow is for the SAME poster → replaces it (a 200 replay '
        'on a second tap must refresh the flow) and returns true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final first = CheckoutFlowState(
        reservation: _reservation(),
        posterSnapshot: _poster(),
      );
      container.read(checkoutFlowProvider.notifier).start(first);
      final replay = CheckoutFlowState(
        reservation: _reservation(),
        posterSnapshot: _poster(),
      );

      final accepted = container
          .read(checkoutFlowProvider.notifier)
          .startIfOwnedBy('p1', replay);

      expect(accepted, isTrue);
      expect(container.read(checkoutFlowProvider), same(replay));
      expect(container.read(checkoutFlowProvider), isNot(same(first)));
    });

    test('the open flow is for ANOTHER poster → leaves it untouched and '
        'returns false. 🔴 mutation-locking: turning this back into an '
        'unconditional write turns this red', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final flowB = CheckoutFlowState(
        reservation: _reservation(id: 'r-b', posterId: 'p2'),
        posterSnapshot: _poster(id: 'p2'),
      );
      container.read(checkoutFlowProvider.notifier).start(flowB);
      final lateA = CheckoutFlowState(
        reservation: _reservation(id: 'r-a', posterId: 'p1'),
        posterSnapshot: _poster(id: 'p1'),
      );

      final accepted = container
          .read(checkoutFlowProvider.notifier)
          .startIfOwnedBy('p1', lateA);

      expect(accepted, isFalse);
      expect(container.read(checkoutFlowProvider), same(flowB));
      expect(container.read(checkoutFlowProvider)!.reservation.id, 'r-b');
      expect(
        container.read(checkoutFlowProvider)!.reservation.id,
        isNot('r-a'),
      );
    });

    test('the owner is the posterId argument, judged against the OPEN '
        "flow's reservation.posterId — not against the offered flow's "
        'own snapshot', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final flowB = CheckoutFlowState(
        reservation: _reservation(id: 'r-b', posterId: 'p2'),
        posterSnapshot: _poster(id: 'p2'),
      );
      container.read(checkoutFlowProvider.notifier).start(flowB);
      final offered = CheckoutFlowState(
        reservation: _reservation(id: 'r-b2', posterId: 'p2'),
        posterSnapshot: _poster(id: 'p2'),
      );

      // Same reservation.posterId as the open flow, but the caller claims
      // to own p1 — the gate answers for the caller, so this is a reject.
      expect(
        container
            .read(checkoutFlowProvider.notifier)
            .startIfOwnedBy('p1', offered),
        isFalse,
      );
      expect(container.read(checkoutFlowProvider), same(flowB));
    });
  });

  test('clear() ends the flow', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(checkoutFlowProvider.notifier)
        .start(
          CheckoutFlowState(
            reservation: _reservation(),
            posterSnapshot: _poster(),
          ),
        );
    container.read(checkoutFlowProvider.notifier).clear();

    expect(container.read(checkoutFlowProvider), isNull);
  });

  test('CheckoutFlowState.stopwatch starts running at construction, not at '
      'first read — this is the anchor reservationCountdownProvider relies '
      'on to never touch DateTime.now()', () async {
    final flow = CheckoutFlowState(
      reservation: _reservation(),
      posterSnapshot: _poster(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(flow.stopwatch.elapsed, greaterThan(Duration.zero));
  });
}
