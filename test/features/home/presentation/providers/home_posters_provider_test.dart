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

  /// Stands in for the backend itself rather than for one canned response:
  /// it slices [catalog] by whatever `limit`/`offset` it is handed. The
  /// pagination tests below are about *which* windows get requested and how
  /// they are stitched together, which a fixed response can't express.
  void stubCatalog(List<PosterSummary> catalog) {
    when(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((invocation) async {
      final limit = invocation.namedArguments[#limit] as int;
      final offset = invocation.namedArguments[#offset] as int;
      return PaginatedPosters(
        items: catalog.skip(offset).take(limit).toList(),
        total: catalog.length,
        limit: limit,
        offset: offset,
      );
    });
  }

  List<PosterSummary> catalogOf(int count, {String prefix = 'p'}) =>
      List.generate(count, (i) => _summary(id: '$prefix$i'));

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
      ).thenThrow(const CatalogException(code: 'server_error'));
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
    ).thenThrow(const CatalogException(code: 'network_error'));
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
      ).thenThrow(const CatalogException(code: 'network_error'));
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

  group('loadMore()', () {
    test(
      'appends the next page at the offset the grid actually holds',
      () async {
        stubCatalog(catalogOf(45));
        final container = makeContainer();
        final first = await container.read(homePostersProvider.future);
        expect(first.items, hasLength(20));
        expect(first.hasMore, isTrue);

        await container.read(homePostersProvider.notifier).loadMore();

        final state = container.read(homePostersProvider).value!;
        expect(state.items, hasLength(40));
        expect(state.items.first.id, 'p0');
        expect(state.items.last.id, 'p39');
        expect(state.total, 45);
        expect(state.isLoadingMore, isFalse);
        verify(() => repository.listPosters(limit: 20, offset: 20)).called(1);
      },
    );

    test(
      'keeps going to the end of the catalog, then stops offering more',
      () async {
        stubCatalog(catalogOf(45));
        final container = makeContainer();
        await container.read(homePostersProvider.future);
        final notifier = container.read(homePostersProvider.notifier);

        await notifier.loadMore();
        await notifier.loadMore();

        final state = container.read(homePostersProvider).value!;
        expect(state.items, hasLength(45));
        expect(state.hasMore, isFalse);

        // Nothing left to fetch — the third tap must not hit the backend for a
        // page the backend has already said does not exist.
        clearInteractions(repository);
        await notifier.loadMore();
        verifyNever(
          () => repository.listPosters(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        );
      },
    );

    test('a row that shifted between pages is not shown twice', () async {
      // `GET /posters` pages by offset over `created_at DESC`, so a poster
      // listed between the two requests pushes the boundary row into the
      // next window as well.
      final catalog = catalogOf(30);
      stubCatalog(catalog);
      final container = makeContainer();
      await container.read(homePostersProvider.future);

      stubCatalog([_summary(id: 'brand-new'), ...catalog]);
      await container.read(homePostersProvider.notifier).loadMore();

      final state = container.read(homePostersProvider).value!;
      final ids = state.items.map((poster) => poster.id).toList();
      expect(
        ids.toSet(),
        hasLength(ids.length),
        reason: 'duplicate rows: $ids',
      );
      // 'p19' is the row that arrives in both windows.
      expect(ids.where((id) => id == 'p19'), hasLength(1));
    });

    test('marks the state as loading more without hiding the grid', () async {
      stubCatalog(catalogOf(45));
      final container = makeContainer();
      await container.read(homePostersProvider.future);

      final completer = Completer<PaginatedPosters>();
      when(
        () => repository.listPosters(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) => completer.future);
      final pending = container.read(homePostersProvider.notifier).loadMore();

      final midFlight = container.read(homePostersProvider);
      // The whole point: the extra page loads *next to* the grid, so the
      // AsyncValue must stay in its data case.
      expect(midFlight.isLoading, isFalse);
      expect(midFlight.value!.isLoadingMore, isTrue);
      expect(midFlight.value!.items, hasLength(20));

      completer.complete(
        PaginatedPosters(items: const [], total: 45, limit: 20, offset: 20),
      );
      await pending;
    });

    test(
      'a failed page keeps the grid and reports the failure inline — it '
      'must never replace what the user is reading with an error screen',
      () async {
        stubCatalog(catalogOf(45));
        final container = makeContainer();
        await container.read(homePostersProvider.future);

        const failure = CatalogException(code: 'network_error');
        when(
          () => repository.listPosters(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenThrow(failure);

        await container.read(homePostersProvider.notifier).loadMore();

        final async = container.read(homePostersProvider);
        expect(async.hasError, isFalse);
        expect(async.value!.items, hasLength(20));
        expect(async.value!.isLoadingMore, isFalse);
        expect(async.value!.loadMoreError, same(failure));

        // Retrying re-requests the same window and clears the failure.
        stubCatalog(catalogOf(45));
        await container.read(homePostersProvider.notifier).loadMore();
        final recovered = container.read(homePostersProvider).value!;
        expect(recovered.items, hasLength(40));
        expect(recovered.loadMoreError, isNull);
      },
    );

    test('hammering the button fires exactly one request', () async {
      stubCatalog(catalogOf(100));
      final container = makeContainer();
      await container.read(homePostersProvider.future);
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
        notifier.loadMore(),
        notifier.loadMore(),
        notifier.loadMore(),
      ];

      verify(
        () => repository.listPosters(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).called(1);

      completer.complete(
        PaginatedPosters(
          items: catalogOf(20, prefix: 'q'),
          total: 100,
          limit: 20,
          offset: 20,
        ),
      );
      await Future.wait(taps);
      expect(container.read(homePostersProvider).value!.items, hasLength(40));
    });

    test('a load-more landing mid-refresh joins it instead of appending to a '
        'list that is being rewritten underneath it', () async {
      stubCatalog(catalogOf(45));
      final container = makeContainer();
      await container.read(homePostersProvider.future);
      clearInteractions(repository);

      final completer = Completer<PaginatedPosters>();
      when(
        () => repository.listPosters(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) => completer.future);

      final notifier = container.read(homePostersProvider.notifier);
      final refreshing = notifier.refresh();
      final loading = notifier.loadMore();

      verify(
        () => repository.listPosters(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).called(1);

      completer.complete(
        PaginatedPosters(items: catalogOf(20), total: 45, limit: 20, offset: 0),
      );
      await Future.wait([refreshing, loading]);
      expect(container.read(homePostersProvider).value!.items, hasLength(20));
    });

    test('does nothing before the first page has landed', () async {
      when(
        () => repository.listPosters(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenThrow(const CatalogException(code: 'network_error'));
      final container = makeContainer();
      await expectLater(
        container.read(homePostersProvider.future),
        throwsA(isA<CatalogException>()),
      );
      clearInteractions(repository);

      await container.read(homePostersProvider.notifier).loadMore();

      verifyNever(
        () => repository.listPosters(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      );
      expect(container.read(homePostersProvider).hasError, isTrue);
    });
  });

  group('refresh() over a paged grid', () {
    test('re-reads everything the user has paged to, not just the first page '
        '— a poster three pages down can sell too', () async {
      stubCatalog(catalogOf(80));
      final container = makeContainer();
      await container.read(homePostersProvider.future);
      await container.read(homePostersProvider.notifier).loadMore();
      expect(container.read(homePostersProvider).value!.items, hasLength(40));
      clearInteractions(repository);

      await container.read(homePostersProvider.notifier).refresh();

      verify(() => repository.listPosters(limit: 40, offset: 0)).called(1);
      final state = container.read(homePostersProvider).value!;
      expect(state.items, hasLength(40));
      // The user stays where they were: refreshing must not snap the grid
      // back to one page under them.
      expect(state.items.last.id, 'p39');
    });

    test('splits a span past the contract ceiling into chunks instead of '
        'sending a limit the backend would reject with 422', () async {
      stubCatalog(catalogOf(200));
      final container = makeContainer();
      await container.read(homePostersProvider.future);
      final notifier = container.read(homePostersProvider.notifier);
      for (var i = 0; i < 5; i++) {
        await notifier.loadMore();
      }
      expect(container.read(homePostersProvider).value!.items, hasLength(120));
      clearInteractions(repository);

      await notifier.refresh();

      // `GetPosters.maxLimit` is 100 (`limit: maximum: 100` in the contract).
      verify(() => repository.listPosters(limit: 100, offset: 0)).called(1);
      verify(() => repository.listPosters(limit: 20, offset: 100)).called(1);
      expect(container.read(homePostersProvider).value!.items, hasLength(120));
    });

    test('a refresh that finds the catalog shrunk drops the rows that are '
        'gone rather than keeping ghosts on screen', () async {
      stubCatalog(catalogOf(45));
      final container = makeContainer();
      await container.read(homePostersProvider.future);
      await container.read(homePostersProvider.notifier).loadMore();
      expect(container.read(homePostersProvider).value!.items, hasLength(40));

      stubCatalog(catalogOf(5));
      await container.read(homePostersProvider.notifier).refresh();

      final state = container.read(homePostersProvider).value!;
      expect(state.items, hasLength(5));
      expect(state.total, 5);
      expect(state.hasMore, isFalse);
    });
  });

  test('refresh() recovers from an error state back to data', () async {
    when(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenThrow(const CatalogException(code: 'network_error'));
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
