import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_routes.dart';
import 'providers/checkout_flow_provider.dart';

/// Ends the checkout flow when the user actually leaves
/// [AppRoutes.checkoutPath] — and only then. Same shape and same reasoning
/// as `OtpFlowObserver` (`features/auth/presentation/otp_flow_observer.dart`)
/// — see that class's doc comment for the table of what fires on a
/// `GoRouter.refresh()` versus a real departure; `didPop` is the only one of
/// the three that doesn't fire on a rebuild that never left the route, and
/// also the only one that covers Android back / iOS back-gesture as well as
/// an on-screen button.
///
/// Covers leaving by success too: `OrderCreatedView`'s "กลับหน้าแรก" does
/// `context.go(homePath)`, which unwinds the pushed `/checkout` route and
/// reports `didPop` for it — no separate "clear on success" call needed.
class CheckoutFlowObserver extends NavigatorObserver {
  CheckoutFlowObserver(this._ref) {
    _ref.onDispose(() => _disposed = true);
  }

  final Ref _ref;
  bool _disposed = false;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name != AppRoutes.checkoutName) return;

    // Deferred by one event-loop turn — writing to a provider mid-build
    // throws in Riverpod, and a `go()`-driven pop is reported from inside
    // the navigator's own build (same fix `OtpFlowObserver` uses).
    final CheckoutFlowState? leaving = _ref.read(checkoutFlowProvider);
    Future<void>(() {
      if (_disposed) return;
      if (!identical(_ref.read(checkoutFlowProvider), leaving)) return;
      _ref.read(checkoutFlowProvider.notifier).clear();
    });
  }
}
