import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A bump counter [AuthInterceptor] increments when it clears tokens because
/// the refresh token was missing or rejected — i.e. the backend session is
/// dead and no client-side recovery is possible.
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
