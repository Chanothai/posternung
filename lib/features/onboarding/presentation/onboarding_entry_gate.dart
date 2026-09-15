import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/startup_trace.dart';
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
/// 🔴 **‹Rewritten 2026-09-15 · ADR-0036 D2 · INF-40 step 4› The paragraph
/// that stood here described a retry ladder that no longer runs.** It read:
/// *"when an `AsyncNotifier.build()` does throw, riverpod 3.3.2 retries it on
/// its own, and while that ladder runs the state is
/// `AsyncLoading(hasError: true)` — not `AsyncError`. `.when` reports that as
/// `loading`, so a restore that keeps failing sits in `loading` until the
/// retries stop."* That was accurate, and it was the mechanism behind the
/// ~38-second spinner at `/home` (symptom ③ of INF-40).
///
/// `backendSessionProvider` now sets `retry: (_, _) => null`, so a `build()`
/// that throws reaches `AsyncError` on the next frame and `error:` below is
/// taken straight away. A failing restore now lands the reader on the intro
/// *immediately* instead of after the 2 s deadline — earlier than before, and
/// for a better reason: because the session is known to have failed, not
/// because waiting was given up on.
///
/// `AuthGate` no longer shares the blind spot either: it decides its error
/// branch from `hasError` before `.when()` sees the state (ADR-0036 **D1**),
/// and carries its own 5 s deadline for the *pending-forever* case (**D3**),
/// which is the one thing `hasError` cannot see.
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
      OnboardingEntryGateState();
}

/// Public only so a widget test can read [debugDeadlineIsActive].
///
/// 🔴 INF-40 step 3. The first test written for this pumped past the deadline
/// and asserted that no `deadline_fired` line appeared — and **it passed with
/// the fix removed**, so it proved nothing and was replaced by the invariant
/// read below.
///
/// ‹🔴 Corrected 2026-09-15 by `code-critic`. This paragraph used to explain
/// that failure as *"in a widget test go_router disposes route `/` within the
/// transition (~300 ms) and `dispose()` cancels the timer long before it could
/// fire at 2 s"* — stated as a general fact about widget tests, **which is
/// false**, and the same sentence had already been copied into the `BL-130`
/// row of `BACKLOG.md`. `onboarding_session_entry_test.dart` proves the
/// opposite about 60 lines away: give the session until 1900 ms to answer and
/// route `/` is still alive at t=2000, `deadline_fired mounted=true` really
/// fires, and a behavioural test of exactly this defect is possible — that
/// test exists and is green.›
///
/// What was actually true is narrower: **that** harness answered the session
/// immediately, so `/` was disposed within the transition and the timer went
/// with it. The scenario the assertion was about never occurred, which is the
/// shape `test-quality` §2 warns about — a green that comes from the setup,
/// not from the system.
class OnboardingEntryGateState extends ConsumerState<OnboardingEntryGate> {
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

  /// Whether the give-up-waiting timer is still armed — the invariant INF-40
  /// AC-2 is about, readable at the one instant it can be checked: the frame
  /// the gate decides, before the router takes the route away.
  @visibleForTesting
  bool get debugDeadlineIsActive => _deadline?.isActive ?? false;

  @override
  void initState() {
    super.initState();
    StartupTrace.gateInit();
    _deadline = Timer(OnboardingEntryGate.sessionDeadline, () {
      // INF-40 step 1: trace only — reports `mounted` at this instant, does
      // not change what happens next (see below).
      StartupTrace.deadlineFired(mounted: mounted);
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

    if (_stoppedWaiting) {
      // INF-40 step 1: trace only — same early return as before, just named.
      StartupTrace.gateDecision(
        dest: GateDecisionDestination.onboarding,
        via: GateDecisionVia.deadline,
      );
      return const OnboardingPageViewScreen();
    }

    return session.when(
      data: (user) {
        if (user == null) {
          StartupTrace.gateDecision(
            dest: GateDecisionDestination.onboarding,
            via: GateDecisionVia.dataNull,
          );
          return const OnboardingPageViewScreen();
        }
        StartupTrace.gateDecision(
          dest: GateDecisionDestination.home,
          via: GateDecisionVia.dataUser,
        );
        // Same escape hatch, and the same reason, as `requireRouteState`:
        // the decision is only knowable inside `build`, and the only way out
        // of a `build` is to schedule the departure for the next frame and
        // show something meanwhile. What it shows is the loading screen, so
        // the user never sees a frame of the intro they are being spared.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // INF-40 step 1: trace only — fired before the existing
          // `context.mounted` check, carrying that exact value.
          StartupTrace.gateGoHome(mounted: context.mounted);
          // 🔴 INF-40 step 3 (AC-2) — the gate has now made its decision, so
          // the deadline has nothing left to decide. Without this line the
          // timer still fires ~2s in, flips `_stoppedWaiting`, and `build()`
          // hands back `OnboardingPageViewScreen` **on top of a user who is
          // already at `/home`** — measured on a real device at every single
          // cold start of the signed-in path, not occasionally.
          //
          // It survives only because route `/` happens to be disposed first
          // most of the time, which no contract anywhere guarantees; the day
          // `/` outlives the frame (a `StatefulShellRoute`, say) the intro
          // flashes over `/home`, which is what ADR-0023 **D4** forbids
          // outright.
          //
          // 🔴 **Cancelling here and nowhere else is deliberate.** Doing the
          // same on the `user == null` branch would look tidier in the trace
          // and would be a real bug: `_stoppedWaiting` is what stops a
          // session that lands *after* the reader started onboarding from
          // yanking them out of it (D8.2). Kill the timer on that branch and
          // that protection goes with it.
          //
          // 🔴 And it is the **only** mechanism — no `_decided` latch beside
          // it. Two overlapping guards would each keep AC-4's mutation (a)
          // green on its own, which would leave this ticket closed by a test
          // that proves nothing (`test-quality` §2).
          _deadline?.cancel();
          if (context.mounted) context.go(AppRoutes.homePath);
        });
        return const AppLoadingScreen();
      },
      loading: () => const AppLoadingScreen(),
      error: (_, _) {
        // INF-40 step 1 (round 2 correction): this is the terminal-failure
        // branch, not session expiry — see `GateDecisionVia.sessionError`'s
        // doc comment in `startup_trace.dart` for why round 1 had this
        // backwards.
        StartupTrace.gateDecision(
          dest: GateDecisionDestination.onboarding,
          via: GateDecisionVia.sessionError,
        );
        return const OnboardingPageViewScreen();
      },
    );
  }
}
