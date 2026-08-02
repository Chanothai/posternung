import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/catalog_exception.dart';
import 'package:posternung/features/home/presentation/providers/home_posters_provider.dart';
import 'package:posternung/features/poster/domain/entities/paginated_posters.dart';
import 'package:posternung/features/poster/domain/entities/poster_status.dart';
import 'package:posternung/features/poster/domain/entities/poster_summary.dart';
import 'package:posternung/features/poster/domain/repositories/poster_repository.dart';
import 'package:posternung/features/poster/presentation/providers/poster_providers.dart';

class MockPosterRepository extends Mock implements PosterRepository {}

PosterSummary _summary({
  String id = 'p1',
  PosterStatus? status = PosterStatus.available,
}) => PosterSummary(
  id: id,
  title: 'Blade Runner',
  price: '450.00',
  status: status,
  conditionGrade: null,
  eraDecade: 1980,
  studio: 'Warner Bros',
  primaryImageUrl: null,
);

PaginatedPosters _page({List<PosterSummary>? items, int? total}) =>
    PaginatedPosters(
      items: items ?? [_summary()],
      total: total ?? (items ?? [_summary()]).length,
      limit: 20,
      offset: 0,
    );

void main() {
  late MockPosterRepository repository;

  setUp(() {
    repository = MockPosterRepository();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [posterRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  void stubOnce(PaginatedPosters page) {
    when(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => page);
  }

  test(
    'build() fetches the first page with the contract default size',
    () async {
      stubOnce(_page());
      final container = makeContainer();

      final page = await container.read(homePostersProvider.future);

      expect(page.items.single.id, 'p1');
      verify(() => repository.listPosters(limit: 20, offset: 0)).called(1);
    },
  );

  test(
    'build() surfaces a CatalogException as AsyncError without retrying — '
    'auto-retry would leave the user on a spinner with no error to see',
    () async {
      when(
        () => repository.listPosters(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenThrow(
        const CatalogException(
          code: 'server_error',
          message: 'พังที่เซิร์ฟเวอร์',
        ),
      );
      final container = makeContainer();

      await expectLater(
        container.read(homePostersProvider.future),
        throwsA(isA<CatalogException>()),
      );
      expect(container.read(homePostersProvider).hasError, isTrue);
      // Exactly one call: the automatic retry is disabled on this provider.
      verify(
        () => repository.listPosters(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).called(1);
    },
  );

  test('an empty catalog is data with total 0, not an error', () async {
    stubOnce(_page(items: [], total: 0));
    final container = makeContainer();

    final page = await container.read(homePostersProvider.future);

    expect(page.total, 0);
    expect(page.items, isEmpty);
  });

  test(
    'refresh() picks up a poster that sold while the grid was on screen',
    () async {
      stubOnce(_page(items: [_summary(status: PosterStatus.available)]));
      final container = makeContainer();
      await container.read(homePostersProvider.future);
      expect(
        container.read(homePostersProvider).value?.items.single.status,
        PosterStatus.available,
      );

      stubOnce(_page(items: [_summary(status: PosterStatus.sold)]));
      await container.read(homePostersProvider.notifier).refresh();

      expect(
        container.read(homePostersProvider).value?.items.single.status,
        PosterStatus.sold,
      );
    },
  );

  test('refresh() keeps the previous page visible instead of flipping to '
      'AsyncLoading mid-flight', () async {
    stubOnce(_page());
    final container = makeContainer();
    await container.read(homePostersProvider.future);

    when(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return _page();
    });
    final refreshFuture = container
        .read(homePostersProvider.notifier)
        .refresh();

    final midFlight = container.read(homePostersProvider);
    expect(midFlight.hasValue, isTrue);
    expect(midFlight.isLoading, isFalse);

    await refreshFuture;
  });

  test('retry() shows loading first — the error view must not sit there '
      'looking untouched while the request runs', () async {
    when(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenThrow(const CatalogException(code: 'network_error', message: 'พัง'));
    final container = makeContainer();
    await expectLater(
      container.read(homePostersProvider.future),
      throwsA(isA<CatalogException>()),
    );
    expect(container.read(homePostersProvider).hasError, isTrue);

    final completer = Completer<PaginatedPosters>();
    when(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) => completer.future);
    final pending = container.read(homePostersProvider.notifier).retry();

    final midFlight = container.read(homePostersProvider);
    expect(midFlight.isLoading, isTrue);
    // `hasError` deliberately not asserted false: Riverpod 3 attaches the
    // previous state to the new `AsyncLoading` (`copyWithPrevious`), so the
    // old error rides along. `isLoading` is what flipped, and it is what
    // `AsyncValue.when` dispatches on — the widget-level proof that this
    // actually renders as a spinner instead of the untouched error view is
    // in `home_screen_test.dart` ("tapping retry gives immediate visible
    // feedback").

    completer.complete(_page());
    await pending;
    expect(container.read(homePostersProvider).value?.items, hasLength(1));
  });

  test(
    'hammering retry fires exactly one request — the whole point of '
    'disabling auto-retry was to stop stacking calls on the backend',
    () async {
      when(
        () => repository.listPosters(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenThrow(
        const CatalogException(code: 'network_error', message: 'พัง'),
      );
      final container = makeContainer();
      await expectLater(
        container.read(homePostersProvider.future),
        throwsA(isA<CatalogException>()),
      );
      clearInteractions(repository);

      final completer = Completer<PaginatedPosters>();
      when(
        () => repository.listPosters(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) => completer.future);

      final notifier = container.read(homePostersProvider.notifier);
      final taps = [
        notifier.retry(),
        notifier.retry(),
        notifier.retry(),
        notifier.retry(),
        notifier.retry(),
      ];

      verify(
        () => repository.listPosters(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).called(1);

      completer.complete(_page());
      // Every tap resolves off the one shared request, so callers awaiting a
      // later tap (e.g. RefreshIndicator) still get a truthful future.
      await Future.wait(taps);
      expect(container.read(homePostersProvider).value?.items, hasLength(1));
    },
  );

  test('a refresh landing mid-retry joins it instead of starting a second '
      'request', () async {
    final completer = Completer<PaginatedPosters>();
    when(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) => completer.future);
    final container = makeContainer();
    // Kick off build(), which is itself in flight.
    final notifier = container.read(homePostersProvider.notifier);
    completer.complete(_page());
    await container.read(homePostersProvider.future);
    clearInteractions(repository);

    final second = Completer<PaginatedPosters>();
    when(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) => second.future);

    final retrying = notifier.retry();
    final refreshing = notifier.refresh();

    verify(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).called(1);

    second.complete(_page());
    await Future.wait([retrying, refreshing]);
  });

  test('a new retry is allowed once the previous one has finished', () async {
    stubOnce(_page());
    final container = makeContainer();
    await container.read(homePostersProvider.future);
    clearInteractions(repository);

    final notifier = container.read(homePostersProvider.notifier);
    await notifier.retry();
    await notifier.retry();

    verify(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).called(2);
  });

  test('refresh() recovers from an error state back to data', () async {
    when(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenThrow(
      const CatalogException(code: 'network_error', message: 'เน็ตหลุด'),
    );
    final container = makeContainer();
    await expectLater(
      container.read(homePostersProvider.future),
      throwsA(isA<CatalogException>()),
    );

    stubOnce(_page());
    await container.read(homePostersProvider.notifier).refresh();

    expect(container.read(homePostersProvider).hasError, isFalse);
    expect(container.read(homePostersProvider).value?.items, hasLength(1));
  });
}
