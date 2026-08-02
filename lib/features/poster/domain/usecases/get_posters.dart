import '../entities/paginated_posters.dart';
import '../repositories/poster_repository.dart';

/// Fetches one page of the catalog. One class, one action — see
/// `GetPosterDetail` for the same shape.
class GetPosters {
  GetPosters(this._repository);
  final PosterRepository _repository;

  /// The contract's own default page size for `GET /posters`.
  static const int defaultLimit = 20;

  /// The contract's hard ceiling (`limit: maximum: 100`). Exceeding it is a
  /// `422` from the backend, so [call] clamps rather than letting a caller
  /// turn an off-by-one into a failed page load.
  static const int maxLimit = 100;

  Future<PaginatedPosters> call({int limit = defaultLimit, int offset = 0}) =>
      _repository.listPosters(
        limit: limit.clamp(1, maxLimit),
        offset: offset < 0 ? 0 : offset,
      );
}
