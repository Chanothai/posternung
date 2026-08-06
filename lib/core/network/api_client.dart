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
    // `security-baseline` §2 / ADR-0017 OD-2 forbid logging tokens even in
    // debug builds — and on this client that means more than the
    // `Authorization` header. Every token this app has also travels in a
    // request/response *body*: `POST /auth/firebase` sends `{id_token}` and
    // gets back `{access_token, refresh_token}`; `POST /auth/refresh` sends
    // `{refresh_token}` and gets a fresh pair back; `POST /auth/logout`
    // sends `{refresh_token}`. All four run through this same client
    // (`BackendAuthDataSource`), so `requestHeader`/`requestBody`/
    // `responseBody` are **all** off — a per-path filter (`PrettyDioLogger
    // .filter`) was considered instead but rejected: it suppresses request
    // line/status/timing too, not just the body, for whatever it excludes —
    // a bigger loss of debug signal than turning body logging off app-wide,
    // and this app has too few endpoints today for body logging elsewhere
    // to be worth the risk anyway. `request`/`error` stay on: method, URL,
    // and status/timing are not secrets, and are what's actually needed to
    // debug a failed call — see `debugDetail` on `AuthException`/
    // `CatalogException` (ADR-0017 D7) for where the failure detail this
    // used to print instead goes now.
    //
    // 🔴 known residual gap, accepted: `PrettyDioLogger`'s own `onError`
    // still prints `err.response.data` on a bad-response (4xx/5xx) error
    // *regardless* of `responseBody` — that flag only gates the success
    // path (`onResponse`), not `onError`'s. Safe today only because every
    // error response this backend sends is the `{error_code, message,
    // details}` envelope (contract-guaranteed — `ErrorResponse` in
    // `docs/api/openapi.yaml` has no token field), never a body that could
    // carry a token. If a future endpoint's error path could ever echo
    // request data back, this stops being true and needs `error: false`
    // for that path instead.
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true,
        compact: true,
      ),
    );
  }

  return dio;
});
