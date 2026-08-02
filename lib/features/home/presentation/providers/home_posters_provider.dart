import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../poster/domain/entities/poster_summary.dart';
import '../../../poster/domain/usecases/get_posters.dart';
import '../../../poster/presentation/providers/poster_providers.dart';
import '../state/home_posters_state.dart';

/// Drives SCR-03's catalog grid off the real `GET /posters`, one page at a
/// time.
///
/// The ViewModel lives in `features/home/` (it's this screen's state) while
/// the usecase/repository/DTO it reads through live in `features/poster/`,
/// shared by every catalog screen — the feature-first layout and the rule
/// for where cross-feature code goes are in the root `CLAUDE.md`.
/// `AsyncValue` carries loading/data/error for the **first** page; `empty`
/// is `total == 0` inside the data case, `sold_out` is per-row
/// (`PosterSummary.status`), and the two states that only exist *while data
/// is on screen* — loading more, and a failed page — live on
/// [HomePostersState] so neither can wipe out the grid.
class HomePostersViewModel extends AsyncNotifier<HomePostersState> {
  /// Non-null while *any* request this notifier owns is running. All three
  /// entry points funnel through it so a second trigger *joins* the request
  /// in flight rather than starting a competing one — a burst of retry taps,
  /// or a load-more tap arriving while a pull-to-refresh is rewriting the
  /// same list, must not fan out into N requests. Letting that happen would undo the whole point of switching
  /// Riverpod's automatic retry off (see the provider below), and would let
  /// a refresh and an append interleave into a scrambled list.
  Future<void>? _inFlight;

  @override
  Future<HomePostersState> build() async => _fetchSpan(GetPosters.defaultLimit);

  /// Re-reads the catalog from the top, covering at least [count] rows.
  ///
  /// Used for the first load *and* for every refresh, which is why it takes
  /// a span rather than a page: once the user has paged down, refreshing
  /// only the first 20 rows would leave everything below them stale — and
  /// the whole reason SCR-03 refreshes at all is that a poster can sell
  /// while the grid is on screen. The contract caps `limit` at 100
  /// (`GetPosters.maxLimit`), so a deeper list is re-read as consecutive
  /// chunks instead of one oversized request that would 422.
  Future<HomePostersState> _fetchSpan(int count) async {
    final getPosters = ref.read(getPostersProvider);
    // Never below one page: a refresh from the empty or error state has no
    // loaded rows to measure, and must still ask for something.
    final span = math.max(count, GetPosters.defaultLimit);

    final items = <PosterSummary>[];
    var total = 0;
    var offset = 0;
    while (offset < span) {
      final chunk = math.min(span - offset, GetPosters.maxLimit);
      final page = await getPosters(limit: chunk, offset: offset);
      total = page.total;
      items.addAll(page.items);
      // A short chunk means the catalog ended inside it — asking for the
      // next offset would only cost a round trip to be told the same.
      if (page.items.length < chunk) break;
      offset += chunk;
    }

    // Chunks are separate requests, so rows can shift between them exactly
    // as they can between load-more taps; same dedupe, same reason.
    return HomePostersState.fromRows(rows: items, total: total);
  }

  /// Pull-to-refresh. Deliberately does **not** flip to `AsyncLoading`, so
  /// whatever is on screen stays put while the request runs
  /// (`RefreshIndicator` draws its own spinner). It re-reads however far the
  /// user has already paged, rather than snapping the grid back to page one
  /// under them.
  ///
  /// This is SCR-03's answer to the `stock-integrity` skill's mobile
  /// requirement (a poster sold while the user is looking at it): the grid
  /// picks up the new `status` and re-renders that card as unavailable in
  /// place, instead of leaving a stale "available" card sitting there. It is
  /// **user-triggered only** — `HomeScreen` no longer re-fetches on app
  /// resume (see that screen's doc comment for the trade-off).
  Future<void> refresh() =>
      _run(showLoading: false, count: state.value?.items.length ?? 0);

  /// User-triggered retry from `HomePostersErrorView`. Unlike [refresh] this
  /// **does** flip to `AsyncLoading` first: the error view is what's on
  /// screen, there is no data worth preserving underneath it, and a tap that
  /// changes nothing visible reads as a dead button — so the user taps
  /// again. Keeping the two cases in one method is what produced exactly
  /// that: silent retries, stacking up.
  Future<void> retry() =>
      _run(showLoading: true, count: GetPosters.defaultLimit);

  /// Appends the next page to the grid (the "โหลดเพิ่มเติม" button).
  ///
  /// Nothing here touches the `AsyncValue` union: success and failure both
  /// land on [HomePostersState] so the rows already on screen survive
  /// either way. A no-op when there is nothing more to fetch, when the
  /// first page hasn't landed yet, or when another request is already
  /// running.
  Future<void> loadMore() {
    final pending = _inFlight;
    if (pending != null) return pending;

    final current = state.value;
    if (current == null || !current.hasMore) return Future<void>.value();

    // Clears any previous `loadMoreError` in the same assignment, so the
    // footer shows a spinner rather than a stale failure beside it.
    state = AsyncData(current.startedLoadingMore());
    return _track(() => _appendNextPage(current.items.length));
  }

  Future<void> _appendNextPage(int offset) async {
    try {
      final page = await ref.read(getPostersProvider)(
        limit: GetPosters.defaultLimit,
        offset: offset,
      );
      // `state.value` can only be the value set just above — `_inFlight`
      // keeps refresh/retry from having replaced it mid-flight.
      state = AsyncData(state.value!.appended(page));
    } catch (error) {
      // Deliberately swallows everything, `Error`s included, instead of
      // letting it reach `AsyncValue.guard`: a failed *extra* page must
      // degrade to a retry line under the grid, never replace a grid the
      // user is reading with a full-screen error.
      state = AsyncData(state.value!.failedLoadingMore(error));
    }
  }

  Future<void> _run({required bool showLoading, required int count}) {
    final pending = _inFlight;
    if (pending != null) return pending;
    if (showLoading) state = const AsyncLoading();
    return _track(() => _fetchIntoState(count));
  }

  Future<void> _fetchIntoState(int count) async {
    state = await AsyncValue.guard(() => _fetchSpan(count));
  }

  /// Publishes [work] as *the* request in flight and clears the slot when
  /// it settles.
  ///
  /// The clearing deliberately hangs off the future rather than sitting in
  /// a `finally` inside [work]: an `async` body only suspends once it
  /// reaches an `await`, and a data source that throws *synchronously*
  /// (a `DioException` raised while building the request — or, in tests, a
  /// mocktail `thenThrow`) never gets there, so its `finally` would run
  /// before `_inFlight` had been assigned and leave the slot permanently
  /// occupied. Every later tap would then silently join a request that
  /// finished long ago. `Future` callbacks are always delivered in a later
  /// microtask, so this ordering cannot invert.
  Future<void> _track(Future<void> Function() work) =>
      _inFlight = Future<void>.sync(work).whenComplete(() => _inFlight = null);
}

final homePostersProvider =
    AsyncNotifierProvider<HomePostersViewModel, HomePostersState>(
      HomePostersViewModel.new,
      // Riverpod 3 auto-retries a failed `build()` up to 10x with
      // exponential backoff by default for any error that isn't a
      // `ProviderException`/`Error` — a `CatalogException` qualifies. Left
      // on, a dead backend leaves Home spinning for tens of seconds with no
      // way for the user to learn anything is wrong, and this screen's own
      // retry button never renders. See `lib/features/poster/CLAUDE.md`.
      retry: (retryCount, error) => null,
    );
