import 'poster_summary.dart';

/// One page of catalog results (`GET /posters` → `PaginatedPosterList`).
///
/// [total] is the total number of rows matching the query across all pages,
/// **not** `items.length` — the empty state is `total == 0` ("the catalog
/// has nothing"), which is a different thing from an over-large [offset]
/// landing past the end of a non-empty catalog.
class PaginatedPosters {
  const PaginatedPosters({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<PosterSummary> items;
  final int total;
  final int limit;
  final int offset;
}
