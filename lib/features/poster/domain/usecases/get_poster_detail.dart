import '../entities/poster_detail.dart';
import '../repositories/poster_repository.dart';

/// Fetches a single poster's full detail. One class, one action — see
/// `SignOut` (`features/auth/domain/usecases/sign_out.dart`) for the same
/// shape.
class GetPosterDetail {
  GetPosterDetail(this._repository);
  final PosterRepository _repository;

  Future<PosterDetail> call(String posterId) =>
      _repository.getPosterDetail(posterId);
}
