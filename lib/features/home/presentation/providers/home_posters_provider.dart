import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../poster/domain/entities/paginated_posters.dart';
import '../../../poster/presentation/providers/poster_providers.dart';

/// Drives SCR-03's catalog grid off the real `GET /posters`.
///
/// The ViewModel lives in `features/home/` (it's this screen's state) while
/// the usecase/repository/DTO it reads through live in `features/poster/`,
/// shared by every catalog screen — the feature-first layout and the rule
/// for where cross-feature code goes are in the root `CLAUDE.md`.
/// `AsyncValue` already gives the loading/data/error union; `empty` is
/// `total == 0` inside the data case, and `sold_out` is per-row
/// (`PosterSummary.status`), so no hand-rolled sealed state is warranted.
class HomePostersViewModel extends AsyncNotifier<PaginatedPosters> {
  /// Non-null while a re-fetch is running. Both entry points below funnel
  /// through it so a second trigger *joins* the request in flight rather
  /// than starting a competing one — a burst of retry taps, or an app
  /// resume landing mid pull-to-refresh, must not fan out into N requests.
  /// Letting that happen would undo the whole point of switching Riverpod's
  /// automatic retry off (see the provider below).
  Future<void>? _inFlight;

  @override
  Future<PaginatedPosters> build() async => _fetch();

  Future<PaginatedPosters> _fetch() => ref.read(getPostersProvider)();

  /// Background re-fetch for pull-to-refresh and app-resume: deliberately
  /// does **not** flip to `AsyncLoading`, so whatever is on screen stays put
  /// while the request runs (`RefreshIndicator` draws its own spinner).
  ///
  /// This is SCR-03's answer to the `stock-integrity` skill's mobile
  /// requirement (a poster sold while the user is looking at it): the grid
  /// picks up the new `status` and re-renders that card as unavailable in
  /// place, instead of leaving a stale "available" card sitting there.
  Future<void> refresh() => _run(showLoading: false);

  /// User-triggered retry from `HomePostersErrorView`. Unlike [refresh] this
  /// **does** flip to `AsyncLoading` first: the error view is what's on
  /// screen, there is no data worth preserving underneath it, and a tap that
  /// changes nothing visible reads as a dead button — so the user taps
  /// again. Keeping the two cases in one method is what produced exactly
  /// that: silent retries, stacking up.
  Future<void> retry() => _run(showLoading: true);

  Future<void> _run({required bool showLoading}) {
    final pending = _inFlight;
    if (pending != null) return pending;
    if (showLoading) state = const AsyncLoading();
    // `_fetchIntoState()` always suspends at its own `await` before its
    // `finally` can run, so this assignment can never be clobbered by a
    // same-tick completion clearing `_inFlight` first.
    return _inFlight = _fetchIntoState();
  }

  Future<void> _fetchIntoState() async {
    try {
      state = await AsyncValue.guard(_fetch);
    } finally {
      _inFlight = null;
    }
  }
}

final homePostersProvider =
    AsyncNotifierProvider<HomePostersViewModel, PaginatedPosters>(
      HomePostersViewModel.new,
      // Riverpod 3 auto-retries a failed `build()` up to 10x with
      // exponential backoff by default for any error that isn't a
      // `ProviderException`/`Error` — a `CatalogException` qualifies. Left
      // on, a dead backend leaves Home spinning for tens of seconds with no
      // way for the user to learn anything is wrong, and this screen's own
      // retry button never renders. See `lib/features/poster/CLAUDE.md`.
      retry: (retryCount, error) => null,
    );
