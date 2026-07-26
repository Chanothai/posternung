import 'package:dio/dio.dart';

import '../../../../core/error/auth_exception.dart';
import '../../../../core/strings/app_strings.dart';
import '../models/backend_user.dart';
import '../models/token_response.dart';

/// Talks to `posternung-backend`'s JWT auth endpoints. Maps every
/// `DioException` to a domain [AuthException] so nothing above the
/// repository/datasource boundary depends on Dio.
abstract class BackendAuthDataSource {
  /// Exchanges a Firebase `id_token` for a backend session
  /// (`POST /auth/firebase`). Serves every Firebase sign-in provider —
  /// email/password, Google, register (find-or-create) — since the backend
  /// reads `sign_in_provider` from the token itself.
  Future<TokenResponse> firebaseLogin(String idToken);

  /// The current user for [accessToken] (`GET /auth/me`). Throws an
  /// [AuthException] with code `unauthorized` on HTTP 401.
  Future<BackendUser> getMe(String accessToken);

  /// Rotates an expired session (`POST /auth/refresh`).
  Future<TokenResponse> refresh(String refreshToken);
}

class BackendAuthDataSourceImpl implements BackendAuthDataSource {
  BackendAuthDataSourceImpl(this._dio);

  final Dio _dio;

  static const _firebase = '/api/v1/auth/firebase';
  static const _me = '/api/v1/auth/me';
  static const _refresh = '/api/v1/auth/refresh';

  @override
  Future<TokenResponse> firebaseLogin(String idToken) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      _firebase,
      data: {'id_token': idToken},
    );
    return TokenResponse.fromJson(response.data!);
  });

  @override
  Future<BackendUser> getMe(String accessToken) => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      _me,
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return BackendUser.fromJson(response.data!);
  });

  @override
  Future<TokenResponse> refresh(String refreshToken) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      _refresh,
      data: {'refresh_token': refreshToken},
    );
    return TokenResponse.fromJson(response.data!);
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      // The backend replies with a `{error_code, message, details}` envelope
      // (message already Thai) for every AppError — surface it verbatim so the
      // login screen can show the real code + message.
      final data = e.response?.data;
      if (data is Map && data['error_code'] is String) {
        throw AuthException(
          code: data['error_code'] as String,
          message: (data['message'] as String?) ?? AppStrings.authErrorGeneric,
        );
      }

      // No structured envelope (connection failure, gateway/non-JSON 5xx, …)
      // → a stable code + Thai fallback message by failure type.
      final status = e.response?.statusCode;
      if (status == null) {
        throw const AuthException(
          code: 'network_error',
          message: AppStrings.authErrorNetwork,
        );
      }
      if (status >= 500) {
        throw const AuthException(
          code: 'server_error',
          message: AppStrings.authErrorServer,
        );
      }
      throw const AuthException(
        code: 'unknown_error',
        message: AppStrings.authErrorGeneric,
      );
    }
  }
}
