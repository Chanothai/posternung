import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/features/checkout/domain/entities/reservation.dart';
import 'package:posternung/features/checkout/presentation/providers/checkout_flow_provider.dart';
import 'package:posternung/features/checkout/presentation/providers/reservation_countdown_provider.dart';
import 'package:posternung/features/poster/domain/entities/poster_detail.dart';
import 'package:posternung/features/poster/domain/entities/poster_status.dart';

import '../../../../support/manual_stopwatch.dart';

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

/// A 3-second reservation span (`expiresAt - createdAt`), and a
/// [ManualStopwatch] the test advances by hand in lockstep with each
/// `tester.pump(Duration(seconds: 1))` — see that class's doc comment for
/// why a real `Stopwatch` can't be driven by `flutter_test`'s fake clock.
({CheckoutFlowState flow, ManualStopwatch stopwatch}) _flow({
  Duration span = const Duration(seconds: 3),
}) {
  final createdAt = DateTime.utc(2026, 9, 16, 15, 30);
  final stopwatch = ManualStopwatch();
  final flow = CheckoutFlowState(
    reservation: Reservation(
      id: 'r1',
      posterId: 'p1',
      createdAt: createdAt,
      expiresAt: createdAt.add(span),
    ),
    posterSnapshot: _poster(),
    stopwatch: stopwatch,
  );
  return (flow: flow, stopwatch: stopwatch);
}

void main() {
  testWidgets(
    'remaining starts at the reservation span and counts down one second '
    'per tick, reaching Duration.zero and staying there (AC-8/AC-11) — no '
    '`60` anywhere in the provider under test, this fixture uses 3s',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final built = _flow();
      container.read(checkoutFlowProvider.notifier).start(built.flow);
      // Keeps the (auto-dispose) provider alive for the life of this test.
      final sub = container.listen(reservationCountdownProvider, (_, _) {});
      addTearDown(sub.close);

      expect(
        container.read(reservationCountdownProvider),
        const Duration(seconds: 3),
      );

      built.stopwatch.manualElapsed = const Duration(seconds: 1);
      await tester.pump(const Duration(seconds: 1));
      expect(
        container.read(reservationCountdownProvider),
        const Duration(seconds: 2),
      );

      built.stopwatch.manualElapsed = const Duration(seconds: 2);
      await tester.pump(const Duration(seconds: 1));
      expect(
        container.read(reservationCountdownProvider),
        const Duration(seconds: 1),
      );

      built.stopwatch.manualElapsed = const Duration(seconds: 3);
      await tester.pump(const Duration(seconds: 1));
      expect(container.read(reservationCountdownProvider), Duration.zero);

      // Stays at zero on a further tick — never negative.
      built.stopwatch.manualElapsed = const Duration(seconds: 4);
      await tester.pump(const Duration(seconds: 1));
      expect(container.read(reservationCountdownProvider), Duration.zero);
    },
  );

  // Plain `test()`, not `testWidgets()`, on purpose: this assertion only
  // needs a synchronous read right after `clear()`, and doesn't touch fake
  // time at all — running it under `testWidgets`'s fake-async binding would
  // otherwise fail on Riverpod's own internal zero-duration scheduling
  // Timer (`ProviderScheduler`'s vsync-batched refresh, unrelated to
  // `ReservationCountdownNotifier`'s `Timer.periodic`), which never gets a
  // chance to complete without a real widget tree driving frames.
  test('clearing the flow rebuilds to Duration.zero rather than throwing', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final built = _flow(span: const Duration(seconds: 10));
    container.read(checkoutFlowProvider.notifier).start(built.flow);
    final sub = container.listen(reservationCountdownProvider, (_, _) {});
    addTearDown(sub.close);
    expect(
      container.read(reservationCountdownProvider),
      const Duration(seconds: 10),
    );

    container.read(checkoutFlowProvider.notifier).clear();

    expect(container.read(reservationCountdownProvider), Duration.zero);
  });

  testWidgets(
    'disposing the container cancels the periodic timer — B5 mutation M2: '
    'removing `ref.onDispose(() => _timer?.cancel())` leaks a live '
    'Timer.periodic past this test, which flutter_test fails on at '
    'teardown ("A Timer is still pending")',
    (tester) async {
      final container = ProviderContainer();
      final built = _flow(span: const Duration(seconds: 30));
      container.read(checkoutFlowProvider.notifier).start(built.flow);
      final sub = container.listen(reservationCountdownProvider, (_, _) {});
      sub.close();

      container.dispose();

      // Deliberately no `addTearDown(container.dispose)` — already disposed
      // above. Advancing fake time once more gives a leaked timer a chance
      // to fire and be noticed before the test ends.
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
