import '../entities/paginated_posters.dart';
import '../entities/poster_detail.dart';

/// Catalog read operations. Implementations must throw `CatalogException`
/// (from `core/error/`) on failure — never a package-specific exception
/// type — same convention as `AuthRepository`.
abstract class PosterRepository {
  /// `GET /posters/{poster_id}`. Throws `CatalogException(code:
  /// 'POSTER_NOT_FOUND', ...)` when there is no such poster — a poster
  /// that exists but is sold/reserved still returns normally with
  /// `status` set accordingly (ADR-0005 §D5); that is not a failure case.
  Future<PosterDetail> getPosterDetail(String posterId);

  /// `GET /posters` — one page of the catalog, newest first.
  ///
  /// Only `limit`/`offset` are exposed. The contract also defines
  /// `era_decade`, `condition_grade`, `min_price`, `max_price` and
  /// `in_stock_only`, but no screen filters yet — SCR-04 (search/filter) is
  /// where those get added, together with the UI that drives them.
  ///
  /// 🔴 There is **no `sort` parameter** in the contract. The backend orders
  /// by `created_at DESC`, and that is what satisfies BR-05's "the default
  /// sort must not be cheapest-first" — so callers must never re-sort the
  /// returned `PaginatedPosters.items` by price. Doing that client-side
  /// would re-introduce the exact violation the backend already avoids.
  ///
  /// `in_stock_only` defaults to `false` server-side, so a page
  /// legitimately contains `reserved`/`sold` rows. That is data to render
  /// as unavailable (AC-4), not an error and not something to filter out
  /// here.
  Future<PaginatedPosters> listPosters({
    required int limit,
    required int offset,
  });
}
