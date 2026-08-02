import '../../../../core/error/catalog_exception.dart';
import '../../domain/entities/paginated_posters.dart';
import '../../domain/entities/poster_detail.dart';
import '../../domain/repositories/poster_repository.dart';
import '../datasources/poster_remote_data_source.dart';

class PosterRepositoryImpl implements PosterRepository {
  PosterRepositoryImpl(this._remoteDataSource);

  final PosterRemoteDataSource _remoteDataSource;

  @override
  Future<PosterDetail> getPosterDetail(String posterId) async {
    try {
      final model = await _remoteDataSource.getPosterDetail(posterId);
      return model.toEntity();
    } on CatalogException {
      rethrow;
    } catch (e) {
      // toEntity() itself can throw CatalogException (unrecognized status)
      // — already handled above — this catches anything else unexpected so
      // it never reaches the ViewModel as a bare, code-less object.
      throw CatalogException(
        code: 'unexpected_${e.runtimeType}',
        message: e.toString(),
      );
    }
  }

  @override
  Future<PaginatedPosters> listPosters({
    required int limit,
    required int offset,
  }) async {
    try {
      final model = await _remoteDataSource.listPosters(
        limit: limit,
        offset: offset,
      );
      return model.toEntity();
    } on CatalogException {
      rethrow;
    } catch (e) {
      throw CatalogException(
        code: 'unexpected_${e.runtimeType}',
        message: e.toString(),
      );
    }
  }
}
