import 'package:dio/dio.dart';

import '../../../../core/error/catalog_exception.dart';
import '../../../../core/error/debug_log.dart';
import '../models/paginated_posters_model.dart';
import '../models/poster_detail_model.dart';

/// Talks to `posternung-backend`'s public catalog endpoints. Maps every
/// `DioException` to a domain `CatalogException` so nothing above the
/// repository/datasource boundary depends on Dio — same convention as
/// `BackendAuthDataSource`.
abstract class PosterRemoteDataSource {
  /// `GET /posters/{poster_id}` — public, no auth required. Throws
  /// `CatalogException(code: 'POSTER_NOT_FOUND', ...)` on 404.
  Future<PosterDetailModel> getPosterDetail(String posterId);

  /// `GET /posters?limit=&offset=` — public, no auth required. Only these
  /// two query params are sent; the contract's filter params belong to
  /// SCR-04 (see `PosterRepository.listPosters`).
  Future<PaginatedPostersModel> listPosters({
    required int limit,
    required int offset,
  });
}

class PosterRemoteDataSourceImpl implements PosterRemoteDataSource {
  PosterRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  static const _posters = '/api/v1/posters';

  @override
  Future<PosterDetailModel> getPosterDetail(String posterId) =>
      _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '$_posters/$posterId',
        );
        return PosterDetailModel.fromJson(response.data!);
      });

  @override
  Future<PaginatedPostersModel> listPosters({
    required int limit,
    required int offset,
  }) => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      _posters,
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return PaginatedPostersModel.fromJson(response.data!);
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      // The backend replies with a `{error_code, message, details}` envelope
      // (message already Thai) for every AppError, e.g. 404
      // `POSTER_NOT_FOUND` — this is the *only* place `displayMessage` is
      // allowed to come from (ADR-0017 D2). `details[]` is never rendered
      // (D3) — captured as `debugDetail` only.
      final data = e.response?.data;
      if (data is Map && data['error_code'] is String) {
        throw CatalogException(
          code: data['error_code'] as String,
          displayMessage: data['message'] as String?,
          debugDetail: logDebugDetail(
            data['details']?.toString(),
            source: 'catalog_remote_envelope',
          ),
        );
      }

      // No structured envelope (connection failure, gateway/non-JSON 5xx, …)
      // → a stable code; the presentation-layer catalog table maps it to
      // Thai (`catalog_error_display.dart`).
      final status = e.response?.statusCode;
      if (status == null) {
        throw const CatalogException(code: 'network_error');
      }
      if (status >= 500) {
        throw const CatalogException(code: 'server_error');
      }
      throw const CatalogException(code: 'unknown_error');
    } on CatalogException {
      rethrow;
    } catch (e) {
      // Anything besides DioException — a malformed success response that
      // PosterDetailModel.fromJson/toEntity can't parse, etc. — must not
      // escape this datasource as a bare object with no `code` to display.
      // `code` is fixed, never composed from `e.runtimeType` (ADR-0017 D6).
      throw CatalogException(
        code: 'catalog_remote_guard_unexpected',
        debugDetail: logDebugDetail(
          e.toString(),
          source: 'catalog_remote_guard',
        ),
      );
    }
  }
}
