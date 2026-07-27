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

  /// Called when the refresh token itself is missing or rejected — the
  /// session cannot be recovered client-side. `core/` can't import
  /// `features/auth/`, so this is a plain callback the app wires to
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

    try {
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
      }

      final retryOptions = options.copyWith(
        extra: {...options.extra, _retriedKey: true},
        headers: {
          ...options.headers,
          'Authorization': 'Bearer $newAccessToken',
        },
      );
      final retryResponse = await refreshClient.fetch<dynamic>(retryOptions);
      handler.resolve(retryResponse);
    } on DioException {
      // Refresh itself failed (expired/revoked refresh token, or the retry
      // failed for a reason other than another 401) — the session is dead;
      // clear it and let the original error propagate.
      await storage.clear();
      onSessionExpired();
      handler.next(err);
    }
  }
}
