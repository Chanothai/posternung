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

Reservation _reservation() => Reservation(
  id: 'r1',
  posterId: 'p1',
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
