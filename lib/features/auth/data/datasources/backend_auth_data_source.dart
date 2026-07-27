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

  /// Revokes this device's refresh token server-side (`POST /auth/logout`).
  ///
  /// Idempotent by contract — an unknown, expired, or already-revoked token
  /// still answers 204 — so this throws only on transport/server failure,
  /// never on "already logged out".
  ///
  /// **Revokes the refresh token only.** The current access token is a
  /// stateless JWT the backend can't recall, so it keeps working until it
  /// expires on its own (~30 min). Signing out therefore still means
  /// clearing local storage and Firebase too; this call just stops the
  /// session from being renewable.
  Future<void> logout(String refreshToken);
}

class BackendAuthDataSourceImpl implements BackendAuthDataSource {
  BackendAuthDataSourceImpl(this._dio);

  final Dio _dio;

  static const _firebase = '/api/v1/auth/firebase';
  static const _me = '/api/v1/auth/me';
  static const _refresh = '/api/v1/auth/refresh';
  static const _logout = '/api/v1/auth/logout';

  // Unauthenticated by nature — must not carry a (possibly stale/invalid)
  // access token, and must not trigger AuthInterceptor's own refresh-on-401
  // if the backend ever 401s them, which would refresh using the very token
  // this call is trying to obtain/rotate. See core/network/auth_interceptor.dart.
  static Options get _skipAuth => Options(extra: {'skipAuth': true});

  @override
  Future<TokenResponse> firebaseLogin(String idToken) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      _firebase,
      data: {'id_token': idToken},
      options: _skipAuth,
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
      options: _skipAuth,
    );
    return TokenResponse.fromJson(response.data!);
  });

  @override
  Future<void> logout(String refreshToken) => _guard(() async {
    // No Bearer, and skipAuth matters here beyond consistency: without it, a
    // 401 would send AuthInterceptor down its refresh-and-retry path —
    // minting a fresh token pair in the middle of a logout. post<void>
    // because the endpoint answers 204 with an empty body; asking Dio to
    // decode a Map on success would fail.
    await _dio.post<void>(
      _logout,
      data: {'refresh_token': refreshToken},
      options: _skipAuth,
    );
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

      // FastAPI's own request-validation failure (a malformed request body —
      // e.g. an empty `id_token` tripping Pydantic's `min_length=1`) answers
      // 422 with `{detail: [{loc, msg, ...}, ...]}`, not the AppError
      // envelope above. Without this branch it fell through to the generic
      // `unknown_error` case below, which gives no hint what was wrong.
      if (data is Map && data['detail'] is List) {
        final fields = (data['detail'] as List)
            .whereType<Map>()
            .map((d) {
              final loc = d['loc'];
              final field = loc is List && loc.isNotEmpty
                  ? loc.last.toString()
                  : '?';
              return '$field: ${d['msg'] ?? 'invalid'}';
            })
            .join('; ');
        throw AuthException(
          code: 'validation_error',
          message: fields.isEmpty ? AppStrings.authErrorGeneric : fields,
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
    } on AuthException {
      rethrow;
    } catch (e) {
      // Anything besides DioException — a malformed success response that
      // TokenResponse.fromJson/BackendUser.fromJson can't parse, a
      // PlatformException from secure storage, etc. — used to escape this
      // method (and this whole datasource) uncaught, reaching the UI as a
      // bare object with no `code` to display.
      throw AuthException(
        code: 'unexpected_${e.runtimeType}',
        message: e.toString(),
      );
    }
  }
}
