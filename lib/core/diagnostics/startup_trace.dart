import 'package:flutter/foundation.dart';

/// One-line, single-anchor timing trace for the app-entry gate mechanism
/// (INF-40 step 1 — `docs/status/gates/INF-40-gate1.md` in `workspace`).
///
/// This is an **instrument, not a fix**. It exists to let step 2 measure the
/// real, on-device shape of `BL-127` (cold start sometimes lands on
/// onboarding instead of `/home` even though `/auth/me` answered 200) and
/// `BL-130` (`gate_decision` firing twice some rounds) — see
/// `OnboardingEntryGate` and `BackendSessionNotifier` for the mechanism this
/// traces. Nothing in this file may change what either of those decides;
/// every call site this module is wired into is a statement added next to
/// an existing decision, never a new branch.
///
/// ### Single anchor (the one rule that costs the most to get wrong)
///
/// Every `t=` value in every line comes from **the same [Stopwatch]**,
/// created lazily on the first traced event of the process. `BL-127` once
/// had to retract a 582 ms figure because it subtracted a `logcat` timestamp
/// (wall clock, UTC) from an in-app one (monotonic, process-relative) — two
/// different time references, arithmetic across them means nothing. Nothing
/// in this file ever calls `DateTime.now()`; the only way a call site gets a
/// duration into a line (`restore_end`'s `ms=`) is by reading [elapsedMs]
/// twice against this same anchor and subtracting — see
/// `BackendSessionNotifier._restore()` for the pattern.
///
/// ### On/off
///
/// Active when `kDebugMode` is true, or when the release binary was built
/// with `--dart-define=STARTUP_TRACE=true` (step 6 measures a release build,
/// per the gate plan). When inactive: no output call happens at all, from
/// any method here — not a suppressed one, an unmade one — and the only
/// per-call cost is the one `bool` check in [_line].
///
/// Lines go out through `debugPrint` so they land in `logcat` (tag
/// `flutter`) and in the `flutter run` console alike — see [_lineAt] for
/// why `dart:developer`'s `log()` was proven unusable here.
///
/// [debugEnabledOverride] and [debugSink] exist for
/// `test/core/diagnostics/startup_trace_test.dart` only. `kDebugMode` is
/// `true` for the entire life of a `flutter test` process (it is not a
/// release/profile build), so the compile-time flag alone can never be
/// driven `false` from a test — there is no seam without one. Production
/// code must never set either field (or call [debugReset]) — a source scan
/// in that same test file (round 2, GATE 1 follow-up) checks that no file
/// under `lib/` other than this one references them at all, so the rule is
/// enforced structurally, not by convention.
///
/// ### Security (OWASP Mobile M2 — `security-baseline` §2)
///
/// `STARTUP_TRACE=true` is a real release flag, so a line built here can end
/// up in a shipped binary's log output. The rule GATE 1 added: **the type
/// system, not caller discipline, decides what can reach a line.** Every
/// public method below takes only [Duration], `int`, `bool`, or one of this
/// file's own closed enums — there is no overload, no `Object`/`dynamic`
/// parameter, and no `Map` on the path from a call site to the output.
/// A session, a user, a token, or a raw backend response body is not
/// *filtered out* here; there is no parameter shape that could ever carry
/// one in. `test/core/diagnostics/startup_trace_test.dart` scans this file's
/// source to keep that true, the same way
/// `test/core/error_message_safety_test.dart` scans `lib/` for the tokens
/// ADR-0017 bans.
///
/// 🔴 Round 2 correction (coordinator, 2026-09-10): `restore_end` no longer
/// carries a `status=` field at all — see [restoreEnd]'s doc comment for why
/// dropping it is more honest than a field that could only ever read `null`.
abstract final class StartupTrace {
  StartupTrace._();

  static const bool _kCompileTimeEnabled =
      kDebugMode || bool.fromEnvironment('STARTUP_TRACE');

  /// Test-only. See the class doc comment for why this seam has to exist.
  @visibleForTesting
  static bool? debugEnabledOverride;

  /// Test-only replacement for the output call [_line] makes.
  /// Production code must never set this — left `null`, every line goes
  /// through `debugPrint`, which is the only channel this module ever
  /// uses outside a test.
  @visibleForTesting
  static void Function(String line)? debugSink;

  /// Test-only. Resets every piece of test-mutable static state this file
  /// owns — [debugEnabledOverride], [debugSink], and the
  /// `_sessionExpiryFired` correlation flag [gateDecision] reads — in one
  /// call, so a test's `tearDown` cannot reset two of the three fields and
  /// silently leak the flag into the next test. Added at round 2 specifically
  /// because that flag is a *third* piece of static state living here.
  @visibleForTesting
  static void debugReset() {
    debugEnabledOverride = null;
    debugSink = null;
    _sessionExpiryFired = false;
  }

  /// Whether a call to any method on this class produces a line right now.
  static bool get enabled => debugEnabledOverride ?? _kCompileTimeEnabled;

  static Stopwatch? _anchor;

  /// Milliseconds since the first traced event of this process, read from
  /// the single anchor [Stopwatch] (created lazily, here, on first use).
  /// Returns `0` without ever creating the [Stopwatch] when [enabled] is
  /// `false` — the "no measurable cost when off" half of the contract.
  static int elapsedMs() {
    if (!enabled) return 0;
    return (_anchor ??= Stopwatch()..start()).elapsedMilliseconds;
  }

  static void _line(String event, [String fields = '']) =>
      _lineAt(elapsedMs(), event, fields);

  static void _lineAt(int t, String event, [String fields = '']) {
    if (!enabled) return;
    final line = fields.isEmpty
        ? 't=$t event=$event'
        : 't=$t event=$event $fields';
    final sink = debugSink;
    if (sink != null) {
      sink(line);
    } else {
      // 🔴 `debugPrint`, not `dart:developer`'s `log()`. Proven on device
      // 2026-09-10: with `log(name: 'startup_trace')` the trace reached
      // **neither** `logcat` **nor** the `flutter run` console — zero lines,
      // while `PrettyDioLogger` (which prints) showed up in both. `log()`
      // publishes to the VM service Logging stream; nothing mirrors that to
      // the process stdout the engine forwards to `logcat`. Step 6 measures a
      // **release** build, which has no VM service at all, so that channel
      // could never have worked there either. The `startup_trace ` prefix is
      // what step 2/6 greps for.
      //
      // 🔴 The release channel is **verified, not assumed** (owner's order at
      // GATE 1: prove it now, not at step 6 — the output channel has already
      // broken once). `flutter build apk --release --flavor sit
      // --dart-define=STARTUP_TRACE=true`, installed on the Xiaomi M2003J15SC
      // (Android 12), 2026-09-10: 7 `startup_trace` lines in `logcat`, tag
      // `flutter`, priority `I`. So `enabled` really does turn on in a release
      // binary through `bool.fromEnvironment`, and `debugPrint` really does
      // survive the release build — neither is inferred.
      debugPrint('startup_trace $line');
    }
  }

  // --- lib/features/onboarding/presentation/onboarding_entry_gate.dart ---

  /// `OnboardingEntryGate.initState()` — the first event of a cold start on
  /// this gate.
  static void gateInit() => _line('gate_init');

  /// Set the instant [sessionExpiryFired] is called, for the life of the
  /// process (never cleared by production code — only [debugReset], for
  /// tests). This is the correlation state that lets [gateDecision] tell a
  /// real "no session was ever stored" apart from "a session existed and was
  /// just invalidated" — both reach the gate as the exact same `data(null)`
  /// value, and the gate itself has no way to tell them apart (see
  /// [GateDecisionVia]'s doc comment for the full story of why this had to
  /// move here instead of staying a plain parameter at the call site).
  static bool _sessionExpiryFired = false;

  /// One decision the gate has computed — [dest] is what it is about to
  /// render/navigate to, [via] is which branch produced it. Fired **every
  /// time** the gate's `build()` reaches a decisive branch, deliberately
  /// including a second time on the same mount (`BL-130`) — this instrument
  /// reports what happens, it does not de-duplicate it.
  ///
  /// 🔴 **`via: GateDecisionVia.dataNull` is upgraded to
  /// [GateDecisionVia.sessionExpiry] here** when [_sessionExpiryFired] is
  /// `true` — the call site (`OnboardingEntryGate`) always passes `dataNull`
  /// for `session.when()`'s `data(null)` branch, exactly as it did before
  /// round 2, because the gate genuinely cannot distinguish the two cases on
  /// its own (both are `data(null)`; nothing in the value itself says why).
  /// Doing the upgrade here — not at the call site — is the whole point:
  /// the gate must not grow a second way to read session state (the same
  /// reasoning ADR-0023 D4 already gives for keeping this gate's error
  /// handling thin), and correlating two *separate trace events* is exactly
  /// a diagnostics-layer concern, not a gate concern. Any value passed as
  /// `via` other than `dataNull` passes through unchanged.
  static void gateDecision({
    required GateDecisionDestination dest,
    required GateDecisionVia via,
  }) {
    final effectiveVia =
        (via == GateDecisionVia.dataNull && _sessionExpiryFired)
        ? GateDecisionVia.sessionExpiry
        : via;
    _line('gate_decision', 'dest=${dest._wire} via=${effectiveVia._wire}');
  }

  /// Immediately before the gate calls `context.go(AppRoutes.homePath)`,
  /// carrying `context.mounted` at that exact instant — the value `BL-130`
  /// needs to tell "still on screen, about to navigate" apart from "already
  /// gone, navigating would throw/no-op".
  static void gateGoHome({required bool mounted}) =>
      _line('gate_go_home', 'mounted=$mounted');

  /// Inside `OnboardingEntryGate`'s deadline `Timer` callback, before the
  /// existing `if (mounted) setState(...)` guard — [mounted] is `State
  /// .mounted` at that instant, not whether the flag ends up flipping.
  static void deadlineFired({required bool mounted}) =>
      _line('deadline_fired', 'mounted=$mounted');

  // --- lib/features/auth/presentation/providers/backend_session_provider.dart ---

  /// The start of `BackendSessionNotifier._restore()`. Returns the anchor
  /// reading at that instant so the caller can compute `restore_end`'s `ms=`
  /// by subtracting a later [elapsedMs] read from this same anchor — never
  /// a second clock.
  static int restoreStart() {
    final start = elapsedMs();
    _lineAt(start, 'restore_start');
    return start;
  }

  /// Immediately before `BackendAuthDataSource.getMe(...)` is called —
  /// [attempt] tells the first call inside `_restore()` apart from the
  /// second one `_refreshAndRetry()` makes after a token refresh, which
  /// would otherwise be indistinguishable in the trace.
  static void authMeSent({required AuthMeAttempt attempt}) =>
      _line('auth_me_sent', 'attempt=${attempt._wire}');

  /// Every exit of `_restore()`/`_refreshAndRetry()` — [outcome] is a closed
  /// classification of which one, and [elapsed] the wall-clock-free duration
  /// since the matching [restoreStart] (i.e.
  /// `Duration(milliseconds: elapsedMs() - startMs)`).
  ///
  /// 🔴 **Deliberately no `status=` field (round 2 correction).** Round 1
  /// added one typed `int?` and wired every call site to pass `null`,
  /// because `AuthException` (the only thing `_restore()` ever catches)
  /// carries a `code` string, never an HTTP status int — getting a real one
  /// to this call site would mean widening `AuthException`'s public shape, a
  /// fourth file this ticket is not allowed to touch. A field that can only
  /// ever read `null` is worse than no field: it *looks* like evidence.
  /// [outcome] already answers what AC-1 needs — `RestoreOutcome.user` is
  /// only ever reached after `BackendAuthDataSource.getMe(...)` returns
  /// successfully, which cannot happen on anything but a 2xx — so
  /// `outcome=user` **is** the proof of a 2xx `GET /auth/me`, honestly
  /// stated as what it actually is instead of a status code nothing here
  /// can ever supply.
  static void restoreEnd({
    required RestoreOutcome outcome,
    required Duration elapsed,
  }) => _line(
    'restore_end',
    'outcome=${outcome._wire} ms=${elapsed.inMilliseconds}',
  );

  /// `BackendSessionNotifier.build()`'s existing
  /// `ref.listen(sessionExpiryProvider, ...)` callback, on the branch that
  /// actually flips `state` — not on every provider tick. Also latches
  /// [_sessionExpiryFired] for [gateDecision] to read — see that method's
  /// doc comment.
  static void sessionExpiryFired() {
    _sessionExpiryFired = true;
    _line('session_expiry_fired');
  }
}

/// Where a [StartupTrace.gateDecision] is about to send the user.
enum GateDecisionDestination { home, onboarding }

extension on GateDecisionDestination {
  String get _wire => switch (this) {
    GateDecisionDestination.home => 'home',
    GateDecisionDestination.onboarding => 'onboarding',
  };
}

/// Which branch of `OnboardingEntryGate` produced a
/// [StartupTrace.gateDecision] — closed at exactly these five (INF-40 gate
/// plan §3, corrected at round 2):
///
/// - [dataUser] — `session.when()`'s `data:` branch, restored user non-null.
/// - [dataNull] — `session.when()`'s `data:` branch, restored user `null`,
///   **and no [StartupTrace.sessionExpiryFired] has happened yet this
///   process** — i.e. this really does look like "nobody was ever signed
///   in", the case `_restore()` returns bare `null` for (no token / a
///   transient infra failure / a cleared token — see [GateDecisionVia] on
///   `RestoreOutcome`'s cousin for that finer split).
/// - [sessionExpiry] — the exact same `data(null)` branch, but with a prior
///   [StartupTrace.sessionExpiryFired] in this process — the case where a
///   session *did* exist and `AuthInterceptor` cleared it on a 401. The gate
///   cannot tell these two `data(null)` cases apart by itself; see
///   [StartupTrace.gateDecision]'s doc comment for why the correlation lives
///   in the trace module instead.
/// - [deadline] — the `_stoppedWaiting` early return.
/// - [sessionError] — `session.when()`'s `error:` branch: `build()` threw
///   and the failure reached a terminal `AsyncError` — today that is only
///   reachable through `flutter_secure_storage` throwing a
///   `PlatformException` (`token_storage.dart` has no `catch` at all), per
///   ADR-0036's Context section. **Round 1 named this value `sessionExpiry`
///   — that was wrong**, confirmed by reading `auth_interceptor.dart` and
///   `backend_session_provider.dart` together: a real session-expiry event
///   sets `state = AsyncData(null)` directly, which is [dataNull]/
///   [sessionExpiry] above, never `error:`. Round 1's mapping would have put
///   the label on the *other* branch from the one that is actually expiry —
///   exactly the third mislabeled round BL-127 warned about.
enum GateDecisionVia {
  dataUser,
  dataNull,
  sessionExpiry,
  deadline,
  sessionError,
}

extension on GateDecisionVia {
  String get _wire => switch (this) {
    GateDecisionVia.dataUser => 'data_user',
    GateDecisionVia.dataNull => 'data_null',
    GateDecisionVia.sessionExpiry => 'session_expiry',
    GateDecisionVia.deadline => 'deadline',
    GateDecisionVia.sessionError => 'session_error',
  };
}

/// Which `GET /auth/me` call a [StartupTrace.authMeSent] refers to —
/// `_restore()`'s own call, or the second one `_refreshAndRetry()` makes
/// after rotating the token.
enum AuthMeAttempt { first, retry }

extension on AuthMeAttempt {
  String get _wire => switch (this) {
    AuthMeAttempt.first => 'first',
    AuthMeAttempt.retry => 'retry',
  };
}

/// How `BackendSessionNotifier._restore()`/`_refreshAndRetry()` exited —
/// closed at exactly these four (INF-40 gate plan §3): [user] (a session was
/// restored), [nullNoToken] (nothing was stored), [nullInfra] (a transient
/// `network_error`/`server_error` left tokens on disk for a later launch),
/// [nullCleared] (tokens were invalid and got wiped).
enum RestoreOutcome { user, nullNoToken, nullInfra, nullCleared }

extension on RestoreOutcome {
  String get _wire => switch (this) {
    RestoreOutcome.user => 'user',
    RestoreOutcome.nullNoToken => 'null_no_token',
    RestoreOutcome.nullInfra => 'null_infra',
    RestoreOutcome.nullCleared => 'null_cleared',
  };
}
