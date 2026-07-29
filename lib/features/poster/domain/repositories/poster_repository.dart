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
}
