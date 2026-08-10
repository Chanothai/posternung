import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_loading_screen.dart';
import 'app_routes.dart';

/// Renders [builder] with [value] when the route has the state it needs, and
/// leaves for [fallbackPath] when it does not.
///
/// **Every route that cannot be built without some piece of state goes
/// through here** (ADR-0018 Amendment 2 A2-D3). Before it existed, `/otp`
/// carried its own hand-written version of this and the next route to need
/// one had nothing to inherit — BL-100 recorded that as the real defect,
/// rather than the crash on `/otp` that made it visible.
///
/// Why a builder cannot simply redirect: a `redirect` is not consulted for
/// an already-resolved match that arrived via `push`, which is exactly the
/// case that goes wrong (go_router 17.4.0, verified — `project-gotchas` §5).
/// So the guard has to be able to act from inside `build`, and the only way
/// out of a `build` is to schedule the departure for the next frame and
/// return something to show in the meantime. The placeholder is
/// [AppLoadingScreen] — the same one `OnboardingEntryGate` shows while the
/// stored session is being restored — so an arrival with no state looks like
/// a moment of loading rather than a flash of a broken screen.
///
/// 🔴 **Pass [value] from a `ref.read`, not a `ref.watch`.** The guard
/// answers "can this route render right now", which is a question about the
/// moment of building. Subscribing would rebuild the route whenever the state
/// is cleared — including the clear that happens on the way out — and the
/// rebuilt guard would see `null` and start navigating to [fallbackPath] on
/// its own.
///
/// How visible that is depends on the route. For `/otp` today it is invisible
/// in the outcome: the screen behind it is the gate at `AppRoutes.homePath`,
/// which is also its fallback, so both paths end in the same place. What is
/// observable even there is that the route rebuilds and leaves at all, which
/// is what `app_router_test.dart` asserts. For the next route whose fallback
/// differs from whatever pushed it, the difference stops being academic — so
/// this is a rule about the helper, not a detail of `/otp`.
Widget requireRouteState<T extends Object>(
  BuildContext context,
  T? value, {
  required Widget Function(T value) builder,
  String fallbackPath = AppRoutes.homePath,
}) {
  if (value == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go(fallbackPath);
    });
    return const AppLoadingScreen();
  }
  return builder(value);
}
