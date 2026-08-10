import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/widgets/app_loading_screen.dart';
import '../../auth/presentation/providers/session_provider.dart';
import 'screens/onboarding_page_view_screen.dart';

/// What sits at [AppRoutes.onboardingPath] — the cold-start location — and
/// decides whether the app opens on onboarding at all.
///
/// **The answer is derived, not stored** (ADR-0023 D1/D2): a user with a
/// usable session is not walked through the intro, and there is no "already
/// seen it" flag anywhere. A signed-out visitor therefore sees onboarding
/// again on the next launch — including right after signing out — which is
/// the decided behavior, not a gap. Adding a flag to change that needs its
/// own ADR first (ADR-0023 §ต้องทำตามมา 1).
///
/// **A widget gate, deliberately not a route-level `redirect`**
/// (ADR-0023 D3), so this is the same shape as `AuthGate` one route over:
/// watch the session, render per branch. A `redirect` would need
/// `refreshListenable` and a `GoRouter.refresh()` — the first in `lib/` —
/// which reopens both ADR-0018 D4 and the `refresh()` debt INF-19 recorded.
/// Reversing that needs an ADR-0018 amendment *before* the code changes.
///
/// The four branches are ADR-0023 D4, and the two that are easy to get
/// backwards are worth naming:
///
/// - `loading` shows [AppLoadingScreen], **not** onboarding. Rendering
///   onboarding while `_restore()` is still validating the stored token
///   against `GET /auth/me` would flash the intro at a signed-in user and
///   then yank it away — the same rule ADR-0021 D1 put on the login screen.
/// - `loading` does not last forever: [OnboardingEntryGate.sessionDeadline]
///   caps it (D8), because "eventually correct" and "opens" are not the same
///   promise to someone standing at a bus stop with one bar of signal.
/// - `error` ends at **onboarding**, never at a spinner: a user who cannot
///   open the app because the café wi-fi is bad is worse than a user who
///   sees the intro one extra time. Nothing is shown about the failure here;
///   the session error still reaches the user through `AuthGate` at
///   [AppRoutes.homePath], which routes it through `authErrorDisplayFor`
///   like every other auth screen (ADR-0017 / INF-20). This gate must not
///   grow a second, parallel way to say the same thing.
///
/// 🔴 **`error` is not the offline path, despite the name — and neither is
/// the deadline.** Measured on a device 2026-08-11, wi-fi and data both off
/// with a valid token stored: the user reaches the intro **1362 ms** after
/// the first frame, well inside the 2 s deadline, and the log shows exactly
/// one `/auth/me` attempt — no `/auth/refresh`, no retries. The road taken is
/// `data:`, not `error:` and not the timer.
///
/// That is [BackendSessionNotifier] doing its job: `_restore()` catches
/// `network_error`/`server_error` and returns `null` rather than rethrowing,
/// deliberately leaving the tokens on disk for a later launch. `build()`
/// therefore never throws, so none of what follows is even reached on this
/// path.
///
/// What follows is still true, and is why `error:` stays thin: when an
/// `AsyncNotifier.build()` *does* throw, riverpod 3.3.2 retries it on its own,
/// and while that ladder runs the state is `AsyncLoading(hasError: true)` —
/// not `AsyncError`. `.when` reports that as `loading`, so a restore that
/// keeps failing sits in `loading` until the retries stop. `error:` is for a
/// session that has failed terminally, which is a narrower case than its name
/// suggests. (`AuthGate` has the same shape and the same blind spot at
/// `/home`; pre-existing, tracked as a gap on SCR-02.)
///
/// The deadline earns its keep on a different case than the one it was
/// written for: **slow but successful**. Both roads are covered separately in
/// `onboarding_session_entry_test.dart`, on purpose — a single test would
/// pass on whichever one happened to win.
class OnboardingEntryGate extends ConsumerStatefulWidget {
  const OnboardingEntryGate({super.key});

  /// How long the gate waits for the stored session before it stops waiting
  /// and opens the intro anyway (ADR-0023 **D8**).
  ///
  /// Without it, a user with a stored token and dead wi-fi watched a spinner
  /// for as long as Dio took to give up — up to the 10 s `connectTimeout` in
  /// `core/network/api_client.dart` — where before this gate existed they got
  /// onboarding instantly. That is the failure D4 exists to prevent, arriving
  /// by a different road.
  ///
  /// 🔴 **This is the deadline of this one gate, not an app-wide timeout
  /// policy** (D8.1). Do not "make it consistent" by editing the Dio timeouts
  /// in `api_client.dart`, and do not promote it into something shared: if
  /// INF-05 (cache/refetch policy, BL-58) ever decides a global rule, that
  /// decision absorbs this constant. Two timeout policies nobody can tell
  /// apart is exactly what D8.1 is written to prevent.
  static const Duration sessionDeadline = Duration(seconds: 2);

  @override
  ConsumerState<OnboardingEntryGate> createState() =>
      _OnboardingEntryGateState();
}

class _OnboardingEntryGateState extends ConsumerState<OnboardingEntryGate> {
  Timer? _deadline;

  /// Latched, never unset for the life of this mount.
  ///
  /// Once the gate has given up waiting and shown the intro, a session that
  /// lands a moment later must **not** yank the reader out of the page they
  /// are on. D8.2 prices this decision explicitly: what the user pays is
  /// seeing onboarding one more time, and they only really pay it if they get
  /// to finish it. Their session is not lost either way — `AuthGate` at
  /// [AppRoutes.homePath] picks up the very same `sessionProvider` when they
  /// come out the other side.
  bool _stoppedWaiting = false;

  @override
  void initState() {
    super.initState();
    _deadline = Timer(OnboardingEntryGate.sessionDeadline, () {
      // 🔴 Flipping this flag is the **whole** of what the deadline does.
      // Nothing here cancels the in-flight restore, invalidates the provider
      // or signs anyone out (D8.2) — giving up on waiting is not giving up
      // the session, and a `signOut()`/`invalidate()` on this path would
      // quietly turn a slow network into a logout. The session that lands
      // late is still the one `AuthGate` reads at [AppRoutes.homePath].
      if (mounted) setState(() => _stoppedWaiting = true);
    });
  }

  @override
  void dispose() {
    _deadline?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    if (_stoppedWaiting) return const OnboardingPageViewScreen();

    return session.when(
      data: (user) {
        if (user == null) return const OnboardingPageViewScreen();
        // Same escape hatch, and the same reason, as `requireRouteState`:
        // the decision is only knowable inside `build`, and the only way out
        // of a `build` is to schedule the departure for the next frame and
        // show something meanwhile. What it shows is the loading screen, so
        // the user never sees a frame of the intro they are being spared.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go(AppRoutes.homePath);
        });
        return const AppLoadingScreen();
      },
      loading: () => const AppLoadingScreen(),
      error: (_, _) => const OnboardingPageViewScreen(),
    );
  }
}
