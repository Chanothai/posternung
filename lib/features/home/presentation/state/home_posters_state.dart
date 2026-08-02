import '../../../poster/domain/entities/paginated_posters.dart';
import '../../../poster/domain/entities/poster_summary.dart';

/// SCR-03's catalog view state — the *accumulated* grid, not one page.
///
/// `AsyncValue<PaginatedPosters>` was enough while Home showed a single
/// page; paging needs two things it cannot express, because both happen
/// **while data is already on screen** and neither may replace it:
///
/// * [isLoadingMore] — the next page is in flight. Flipping the provider to
///   `AsyncLoading` here would swap the whole grid for a spinner, losing the
///   user's scroll position on every tap.
/// * [loadMoreError] — the next page failed. Flipping to `AsyncError` would
///   replace an intact grid with a full-screen error over a page the user
///   never asked to be blocked on; the rows already fetched are still valid.
///
/// This is not the sealed-class/MVI shape the root `CLAUDE.md` reserves for
/// cart/checkout: the screen still has one state, with two extra facts
/// hanging off the data case. The `AsyncValue` union above it still carries
/// loading/data/error for the *first* page.
class HomePostersState {
  const HomePostersState({
    required this.items,
    required this.total,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  /// Builds a fresh grid out of rows read in one or more requests, dropping
  /// any id that appears twice — see [appended] for why that happens.
  HomePostersState.fromRows({
    required List<PosterSummary> rows,
    required this.total,
  }) : items = _mergeById(const [], rows),
       isLoadingMore = false,
       loadMoreError = null;

  /// Every row fetched so far, in server order (`created_at DESC`). Never
  /// re-sorted — see `PosterRepository.listPosters` on BR-05.
  final List<PosterSummary> items;

  /// Rows matching the query across *all* pages, as reported by the last
  /// response. The empty state is `total == 0`; [hasMore] is what decides
  /// whether a pager is offered.
  final int total;

  final bool isLoadingMore;

  /// The failure from the last [HomePostersState] page attempt, kept as the
  /// raw error so the footer can pull a `CatalogException`'s own Thai
  /// message out of it — the same treatment `HomePostersErrorView` gives
  /// the first-page failure. Cleared as soon as another attempt starts.
  final Object? loadMoreError;

  /// Whether the backend says there is more than what's on screen.
  ///
  /// Compares against [total] rather than "the last page came back full":
  /// a catalog whose size is an exact multiple of the page size would
  /// otherwise keep offering a button that fetches nothing.
  bool get hasMore => items.length < total;

  HomePostersState startedLoadingMore() =>
      HomePostersState(items: items, total: total, isLoadingMore: true);

  /// Appends [page] to what's on screen, dropping ids already present.
  ///
  /// The dedupe is not defensive padding: `GET /posters` pages by `offset`
  /// over rows ordered `created_at DESC`, so a poster listed between two
  /// requests shifts every later row down by one and the next page re-sends
  /// the row at the boundary. Without this the grid would show it twice —
  /// and Flutter would be handed two cards with matching keys.
  HomePostersState appended(PaginatedPosters page) => HomePostersState(
    items: _mergeById(items, page.items),
    // The freshest count wins: the catalog can grow or shrink under a
    // user who is paging slowly.
    total: page.total,
  );

  HomePostersState failedLoadingMore(Object error) =>
      HomePostersState(items: items, total: total, loadMoreError: error);

  static List<PosterSummary> _mergeById(
    List<PosterSummary> existing,
    List<PosterSummary> incoming,
  ) {
    final seen = existing.map((poster) => poster.id).toSet();
    return [...existing, ...incoming.where((poster) => seen.add(poster.id))];
  }
}
