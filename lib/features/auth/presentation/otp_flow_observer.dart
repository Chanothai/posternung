import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_routes.dart';
import 'providers/otp_flow_provider.dart';

/// Ends the phone-verification flow when the user actually leaves
/// [AppRoutes.otpPath] — and only then.
///
/// Why an observer rather than a lifecycle callback (Amendment 2 A2-D4):
/// the two obvious places to clear from both fire when
/// `GoRouter.refresh()` rebuilds a route the user has not left.
///
/// | tried | what happens on `refresh()` |
/// |---|---|
/// | `State.dispose()` | fires whenever the builder swaps widget type |
/// | `GoRoute.onExit` | **fires**, despite the name |
/// | `NavigatorObserver.didPop` | **silent — not one callback** |
///
/// Verified on go_router 17.4.0. `didPop` is also the only one of the three
/// that covers Android's back button and iOS's back gesture as well as the
/// on-screen button, because all three end at `Navigator.pop`; a handler
/// wired to the button in `OtpVerificationScreen` would miss the other two.
///
/// It covers leaving by success too: `completeAuthFlow`'s
/// `context.go(homePath)` unwinds the pushed route and reports `didPop` for
/// it, so there is no separate "clear on success" call to keep in step.
class OtpFlowObserver extends NavigatorObserver {
  OtpFlowObserver(this._ref) {
    _ref.onDispose(() => _disposed = true);
  }

  final Ref _ref;
  bool _disposed = false;

  /// 🔴 [RouteSettings.name] holds the route's **name** (`otp`), not its path
  /// — go_router only falls back to the path for a `GoRoute` that was
  /// declared without a `name:`. Every route in this app has one, and
  /// `app_router_test.dart` asserts the table's names are exactly
  /// `AppRoutes.allNames`, so comparing against [AppRoutes.otpName] is the
  /// comparison that cannot quietly stop matching.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name != AppRoutes.otpName) return;

    // Leaving by `go` (which is how a successful verification leaves) reports
    // this pop from *inside* the navigator's build, and Riverpod refuses a
    // write during a build — "Tried to modify a provider while the widget
    // tree was building". So the write is deferred by one event-loop turn,
    // which is the fix Riverpod's own error text prescribes.
    final OtpFlowState? leaving = _ref.read(otpFlowProvider);
    Future<void>(() {
      if (_disposed) return;
      // Only clear the flow that was actually on screen. Deferring opens a
      // window in which a *new* flow could have started, and clearing that
      // one would delete state the user is about to need — the same class of
      // mistake as clearing from a lifecycle callback, arrived at from the
      // other direction.
      if (!identical(_ref.read(otpFlowProvider), leaving)) return;
      _ref.read(otpFlowProvider.notifier).clear();
    });
  }
}
