import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A bump counter [AuthInterceptor] increments when it clears tokens because
/// the backend session is dead and no client-side recovery is possible —
/// exactly three situations (`INF-45`, see [AuthInterceptor]'s class doc
/// comment for the full closed table): no refresh token stored, `POST
/// /auth/refresh` itself rejected (401/other 4xx), or the retried request
/// getting a 401 again with the freshly-rotated token. A transient infra
/// failure on either call (5xx, network/timeout) does **not** bump this —
/// that is not proof the session is dead, only that the network is having a
/// bad moment — and neither does the retried request coming back with an
/// ordinary business 4xx (e.g. 409 `BUYER_HAS_LIVE_ORDER`): that response
/// proves the freshly-rotated token was valid.
///
/// Lives in `core/` (not `features/auth/`) because the interceptor that
/// drives it lives in `core/network/`, and `core/` cannot import
/// `features/`. `BackendSessionNotifier` listens to this and clears its own
/// state in response, so the app reacts the same way an explicit sign-out
/// does — no direct dependency between the two layers.
class SessionExpiryNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void markExpired() => state = state + 1;
}

final sessionExpiryProvider = NotifierProvider<SessionExpiryNotifier, int>(
  SessionExpiryNotifier.new,
);
