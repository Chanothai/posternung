import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/api_base_url_resolver.dart';
import '../config/environment_provider.dart';
import 'auth_interceptor.dart';
import 'session_expiry.dart';
import 'token_storage.dart';

/// Must match `BackendAuthDataSource`'s private `_refresh` path — duplicated
/// literally rather than shared because `core/` cannot import
/// `features/auth/` (see `lib/core/CLAUDE.md`).
const _refreshPath = '/api/v1/auth/refresh';

/// Dio's own default is to wait forever on a stalled connection — no
/// timeout at all — so without this a hung request never fails, it just
/// hangs the calling screen indefinitely. Both clients share these values so
/// a timeout on either surfaces identically as `AuthException(code:
/// 'network_error')` (via `BackendAuthDataSource._guard`).
BaseOptions _baseOptions(String baseUrl) => BaseOptions(
  baseUrl: baseUrl,
  connectTimeout: const Duration(seconds: 10),
  sendTimeout: const Duration(seconds: 20),
  receiveTimeout: const Duration(seconds: 20),
);

/// A bare `Dio` with no interceptors, used only by [AuthInterceptor] to call
/// `/auth/refresh` and re-issue a failed request — see the interceptor's doc
/// comment for why it must stay separate from [dioProvider]'s client.
final _refreshDioProvider = Provider<Dio>((ref) {
  final environment = ref.watch(environmentProvider);
  return Dio(_baseOptions(apiBaseUrlFor(environment)));
});

/// Shared `posternung-backend` HTTP client, base URL resolved per
/// [Environment] via [apiBaseUrlFor].
///
/// [AuthInterceptor] auto-attaches the backend access token to every request
/// and transparently refreshes + retries on a 401. In debug builds only, a
/// [PrettyDioLogger] prints each request/response to the run console —
/// stripped from every release build (SIT/UAT/production).
final dioProvider = Provider<Dio>((ref) {
  final environment = ref.watch(environmentProvider);
  final dio = Dio(_baseOptions(apiBaseUrlFor(environment)));

  dio.interceptors.add(
    AuthInterceptor(
      storage: ref.watch(tokenStorageProvider),
      refreshClient: ref.watch(_refreshDioProvider),
      refreshPath: _refreshPath,
      onSessionExpired: () =>
          ref.read(sessionExpiryProvider.notifier).markExpired(),
    ),
  );

  if (kDebugMode) {
    // `requestHeader: true` prints the `Authorization: Bearer …` header — fine
    // for the debug console (never ships in release); set it false if you'd
    // rather keep the access token out of dev logs.
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        error: true,
        compact: true,
      ),
    );
  }

  return dio;
});
