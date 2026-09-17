import 'package:dio/dio.dart';

import 'token_storage.dart';

/// Auto-attaches the backend access token to every outgoing request and
/// transparently refreshes + retries on a 401.
///
/// Extends [QueuedInterceptor] rather than [InterceptorsWrapper] on purpose:
/// Dio processes a `QueuedInterceptor`'s `onError` callbacks for the *same
/// interceptor instance* one at a time, in order — so if N concurrent
/// requests all 401 together, the first one's [onError] runs to completion
/// (refresh + retry) before the second one's even starts. [onError] uses
/// that ordering guarantee: before refreshing, it compares the token the
/// *failing* request was sent with against whatever is in [storage] right
/// now. Requests 2..N were sent with the same (now-stale) token as request
/// 1, but by the time their turn in the queue comes up, request 1 has
/// already stored a new one — so they see a mismatch, skip straight to
/// retrying with the token already in storage, and only request 1 ever
/// actually calls `/auth/refresh`. No hand-rolled `Completer`/lock needed.
///
/// Pass `options.extra['skipAuth'] = true` on a request that must not carry
/// an access token or trigger a refresh (login/register/refresh calls
/// themselves) — see [BackendAuthDataSourceImpl].
///
/// ### When [onSessionExpired] fires — and when it deliberately does not
/// (`INF-45`)
///
/// [onError] only ever reaches one of two outcomes on a 401: "the session is
/// dead, clear it" or "something else went wrong, leave the session alone".
/// The closed table below is what decides which — every branch in the body
/// maps to exactly one row, and no other condition may call [storage].clear
/// or [onSessionExpired]:
///
/// | situation | clear + markExpired? | error sent onward |
/// |---|---|---|
/// | no refresh token stored | yes | the original 401 (`err`) |
/// | `POST /auth/refresh` answers 401/other 4xx | yes | the original 401 (`err`) |
/// | `POST /auth/refresh` answers 5xx | **no** | the refresh failure (`refreshErr`) |
/// | `POST /auth/refresh` network/timeout | **no** | the refresh failure (`refreshErr`) |
/// | retry answers 2xx | — | resolved with the retried response |
/// | retry answers 401 again | yes | the retry failure (`retryErr`) |
/// | retry answers another 4xx (409/422/429/404/…) | **no** | the retry failure (`retryErr`) |
/// | retry answers 5xx | **no** | the retry failure (`retryErr`) |
/// | retry network/timeout | **no** | the retry failure (`retryErr`) |
///
/// The point of splitting "refresh failed" from "retry failed" into two
/// separate `try`/`on DioException` blocks (rather than one `try` wrapping
/// both, as this class used to) is exactly the middle four rows: a
/// **successful** refresh followed by a retry that comes back with a normal
/// business 4xx (say, 409 `BUYER_HAS_LIVE_ORDER` — the buyer already has a
/// live order on this poster) is not a dead session, it is the backend
/// correctly answering a request that *did* carry a valid, freshly-rotated
/// token. Before this fix, both blocks shared one `catch (DioException)`,
/// so that 409 looked identical to an actually-expired refresh token and
/// cleared a perfectly good session out from under the user (`INF-45`).
/// Only a 401 on the retry — the new token itself being rejected — still
/// means the session is dead.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.storage,
    required this.refreshClient,
    required this.refreshPath,
    required this.onSessionExpired,
  });

  final TokenStorage storage;

  /// A bare `Dio` with no interceptors of its own — used for both the
  /// `/auth/refresh` call and re-issuing the original failed request.
  /// Deliberately separate from the main client so refreshing/retrying can
  /// never recurse back into this same interceptor.
  final Dio refreshClient;

  final String refreshPath;

  /// Called when the session cannot be recovered client-side and must be
  /// treated as dead — see the class doc comment's table for the exact
  /// three situations this fires in: no refresh token stored, the refresh
  /// call itself being rejected (401/other 4xx), or the retried request
  /// getting a 401 again with the freshly-rotated token. `core/` can't
  /// import `features/auth/`, so this is a plain callback the app wires to
  /// `sessionExpiryProvider` instead of a direct dependency.
  final void Function() onSessionExpired;

  static const _skipAuthKey = 'skipAuth';
  static const _retriedKey = 'retried';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final skipAuth = options.extra[_skipAuthKey] == true;
    final hasAuthHeader = options.headers.containsKey('Authorization');
    if (!skipAuth && !hasAuthHeader) {
      final accessToken = await storage.readAccessToken();
      if (accessToken != null) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final skipAuth = options.extra[_skipAuthKey] == true;
    final alreadyRetried = options.extra[_retriedKey] == true;

    if (err.response?.statusCode != 401 || skipAuth || alreadyRetried) {
      handler.next(err);
      return;
    }

    // Did a queued 401 ahead of this one already refresh? Compare the
    // token this request failed with against what's in storage right now.
    final currentAccessToken = await storage.readAccessToken();
    final currentBearer = currentAccessToken == null
        ? null
        : 'Bearer $currentAccessToken';
    final failedWithBearer = options.headers['Authorization'] as String?;

    final String newAccessToken;
    if (currentBearer != null && currentBearer != failedWithBearer) {
      // Someone else's refresh already landed — just retry with it.
      newAccessToken = currentAccessToken!;
    } else {
      final refreshToken = await storage.readRefreshToken();
      if (refreshToken == null) {
        await storage.clear();
        onSessionExpired();
        handler.next(err);
        return;
      }

      try {
        final refreshResponse = await refreshClient.post<Map<String, dynamic>>(
          refreshPath,
          data: {'refresh_token': refreshToken},
        );
        final data = refreshResponse.data!;
        newAccessToken = data['access_token'] as String;
        await storage.save(
          accessToken: newAccessToken,
          refreshToken: data['refresh_token'] as String,
        );
      } on DioException catch (refreshErr) {
        final refreshStatus = refreshErr.response?.statusCode;
        if (refreshStatus != null && refreshStatus < 500) {
          // The refresh token itself was rejected (401) or some other 4xx —
          // there is no path left to recover this session client-side.
          await storage.clear();
          onSessionExpired();
          handler.next(err);
        } else {
          // 5xx, or no response at all (network/timeout) — transient infra
          // trouble, not proof the session is dead. Leave tokens intact and
          // let the caller see this failure so it can show a retry, exactly
          // like `_restore()`'s `network_error`/`server_error` handling.
          handler.next(refreshErr);
        }
        return;
      }
    }

    final retryOptions = options.copyWith(
      extra: {...options.extra, _retriedKey: true},
      headers: {...options.headers, 'Authorization': 'Bearer $newAccessToken'},
    );
    try {
      final retryResponse = await refreshClient.fetch<dynamic>(retryOptions);
      handler.resolve(retryResponse);
    } on DioException catch (retryErr) {
      // A fresh token that is itself immediately rejected (401) means the
      // session is dead. Any other outcome — a normal business 4xx like 409
      // `BUYER_HAS_LIVE_ORDER`, a 5xx, or a transport failure — is the
      // retried request's own business, not a session-expiry signal, and
      // must reach the caller as itself rather than as the original 401.
      if (retryErr.response?.statusCode == 401) {
        await storage.clear();
        onSessionExpired();
      }
      handler.next(retryErr);
    }
  }
}
