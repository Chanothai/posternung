import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_routes.dart';
import 'providers/email_verification_flow_provider.dart';

/// Ends the email-verification flow when the user actually leaves
/// [AppRoutes.emailVerificationPath] — and only then.
///
/// Identical mechanism to [OtpFlowObserver] (see that class's doc for the
/// full `refresh()` vs `State.dispose()` vs `GoRoute.onExit` comparison,
/// verified on go_router 17.4.0 by ADR-0018 Amendment 2): `didPop` is the
/// only one of the three that stays silent on a `GoRouter.refresh()` that
/// merely rebuilds the route the user is still standing on, and the only one
/// that covers Android back / iOS back-gesture as well as an on-screen
/// button.
class EmailVerificationFlowObserver extends NavigatorObserver {
  EmailVerificationFlowObserver(this._ref) {
    _ref.onDispose(() => _disposed = true);
  }

  final Ref _ref;
  bool _disposed = false;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name != AppRoutes.emailVerificationName) return;

    // Deferred by one event-loop turn for the same reason OtpFlowObserver
    // defers: leaving by `go` (a successful verification) reports this pop
    // from *inside* the navigator's build, and Riverpod refuses a write
    // during a build.
    final EmailVerificationFlowState? leaving = _ref.read(
      emailVerificationFlowProvider,
    );
    Future<void>(() {
      if (_disposed) return;
      // Only clear the flow that was actually on screen — a new flow could
      // have started in the deferred window.
      if (!identical(_ref.read(emailVerificationFlowProvider), leaving)) {
        return;
      }
      _ref.read(emailVerificationFlowProvider.notifier).clear();
    });
  }
}
