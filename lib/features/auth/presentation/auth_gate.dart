import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/app_spacing.dart';
import '../../../core/strings/app_strings.dart';
import 'auth_error_display.dart';
import 'providers/session_provider.dart';
import 'screens/login_screen.dart';
import 'widgets/auth_error_banner.dart';

/// Gates [builder] behind auth state: shows [LoginScreen] when signed out,
/// otherwise builds the authenticated destination. Watches `sessionProvider`,
/// which since ADR-0021 D1 reports authenticated off the **backend JWT session
/// alone** — a Firebase session with no backend session is a half-finished
/// sign-in, not a signed-in user, and must not advance this gate.
///
/// Two separate protections live here, and ADR-0036 is explicit that they
/// cover **different** failures rather than overlapping:
///
/// - **D1** catches a session that has already *failed*: the error branch is
///   chosen from `hasError`, before `.when()` gets a say.
/// - **D3** catches a session that is *still pending* and may never fail:
///   [sessionErrorDeadline].
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key, required this.builder});

  final WidgetBuilder builder;

  /// ADR-0036 **D3** — how long this gate waits on a session that is neither
  /// answering nor failing before it says so on screen.
  ///
  /// 🔴 **A UX threshold that was proposed, not a number anyone measured**
  /// (D3.3). Every latency figure this project has was taken on an emulator
  /// or a LAN; nobody has measured how long `/auth/me` hangs on real mobile
  /// data. ADR-0036 **OD-1** owns revisiting it, and **OD-5** owns getting
  /// the 4G numbers that would make revisiting it possible. **Do not nudge
  /// this by feel.**
  ///
  /// 🔴 Scope is this gate and nothing else (D3.2): it is **not** a general
  /// timeout policy, and "making things consistent" by editing Dio's
  /// `connectTimeout`/`receiveTimeout` in `api_client.dart` is forbidden —
  /// those are ADR-0023 D8.1's, and INF-40 **AC-5** additionally forbids
  /// closing that ticket by widening a timeout.
  static const Duration sessionErrorDeadline = Duration(seconds: 5);

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

/// ‹🔴 Made private again 2026-09-15 by `code-critic`. It was briefly public,
/// with a `@visibleForTesting debugDeadlineIsActive` getter, "so a widget test
/// can read it" — **no test ever did.** `OnboardingEntryGateState` earns that
/// exception because a test really does read its invariant and mutation (ก)
/// dies because of it; this one bought nothing and widened `lib/`'s public
/// surface on a claim that was untrue the day it was written. What this gate's
/// deadline does is already covered behaviourally by the D3 / D3.1 tests.›
class _AuthGateState extends ConsumerState<AuthGate> {
  Timer? _deadline;

  /// Whether the wait has already run past [AuthGate.sessionErrorDeadline].
  ///
  /// 🔴 **Not latched, and that is the whole point** (ADR-0036 **D3.1**).
  /// `OnboardingEntryGate._stoppedWaiting` *is* latched, deliberately, because
  /// there the user is reading onboarding and yanking them out mid-page costs
  /// more than showing it once too often. Here the user is staring at a screen
  /// that says they cannot get in — taking them in the moment they can is what
  /// they want, not a yank. A latch here would rebuild BL-130, the very bug
  /// INF-40 exists to close, inside the ticket closing it.
  bool _pastDeadline = false;

  /// Set when the reader takes the way out on the problem screen (D4).
  ///
  /// 🔴 Never blocks a session that arrives later: [build] answers "is there a
  /// real user?" **before** it reads this flag, so the D3.1 guarantee — a
  /// session that lands after the deadline still gets you in — holds whether
  /// or not this was pressed.
  bool _showLogin = false;

  @override
  void initState() {
    super.initState();
    _deadline = Timer(AuthGate.sessionErrorDeadline, () {
      // 🔴 Flipping this flag is the **entire** effect of the deadline
      // (ADR-0036 D3.1). Nothing here signs anyone out, invalidates the
      // provider, clears a token or stops listening: the session request is
      // still in flight and may still succeed. Any of those would turn a slow
      // network into a logout, which is exactly what D3.1 forbids.
      if (mounted) setState(() => _pastDeadline = true);
    });
  }

  @override
  void dispose() {
    _deadline?.cancel();
    super.dispose();
  }

  void _goToLogin() => setState(() => _showLogin = true);

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    // 🔴 ADR-0036 **D3.1** — a session that arrives late still gets in.
    //
    // This check comes first on purpose. Whatever the gate is showing (the
    // error screen, the slow-network screen, the login screen the reader
    // asked for) the moment a real session exists, the destination wins.
    // Anything else would be a gate that saw a valid session and kept the
    // user out, which is the failure D3.1 is written to prevent.
    if (session.hasValue && session.value != null) {
      return widget.builder(context);
    }

    if (_showLogin) return const LoginScreen();

    // 🔴 ADR-0036 **D1** — decided here, *before* `.when()`.
    //
    // `hasError` also covers `AsyncLoading(error: …, retrying: true)`, which
    // is the state Riverpod 3 sits in while retrying. `.when()` checks
    // `isLoading` first, so routing error through it returned the spinner for
    // the whole ~38s ladder. D2 switches that ladder off at the provider, and
    // this line makes the screen correct even if some future provider turns
    // retries back on.
    //
    // `!hasValue` is deliberate: someone who already has a session must not be
    // thrown out to an error screen because a refresh failed.
    if (session.hasError && !session.hasValue) {
      final display = authErrorDisplayFor(session.error);
      return _SessionProblemScreen(
        message: display?.message ?? AppStrings.authErrorGeneric,
        code: display?.code,
        onGoToLogin: _goToLogin,
      );
    }

    // 🔴 ADR-0036 **D3** — still pending, past the deadline, nothing has
    // failed. `hasError` above cannot catch this case: there is no error yet
    // and there may not be one for another 15 seconds (`receiveTimeout` is
    // 20s). Without this the user watches a spinner with no way out.
    //
    // Checked *after* the error branch so a session that fails at 6s shows its
    // real message rather than the generic slow-network line.
    if (_pastDeadline && !session.hasValue) {
      return _SessionProblemScreen(
        message: AppStrings.authSessionSlowMessage,
        onGoToLogin: _goToLogin,
      );
    }

    return session.when(
      data: (user) =>
          user == null ? const LoginScreen() : widget.builder(context),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      // Unreachable in practice — the `hasError` branch above wins first — but
      // kept honest rather than `throw`n: `.when()` demands all three, and a
      // branch that lies is worse than one that is merely redundant.
      error: (error, stackTrace) {
        final display = authErrorDisplayFor(error);
        return _SessionProblemScreen(
          message: display?.message ?? AppStrings.authErrorGeneric,
          code: display?.code,
          onGoToLogin: _goToLogin,
        );
      },
    );
  }
}

/// What the user sees when the session cannot be established: the message,
/// and one way out.
///
/// 🔴 The way out is **"เข้าสู่ระบบ" going to [LoginScreen]**, not a retry
/// button (ADR-0036 **D4**). `AuthErrorBanner` gates its retry on
/// `code == oauthLoginConflictCode` because ADR-0021 D3 ties that button to a
/// 409, and these errors carry no HTTP code at all — the rule never covered
/// them, so honouring it needs no amendment. Whether this gate should grow a
/// retry of its own is ADR-0036 **OD-2**, and it stays shut until there are
/// numbers saying it pays.
class _SessionProblemScreen extends StatelessWidget {
  const _SessionProblemScreen({
    required this.message,
    required this.onGoToLogin,
    this.code,
  });

  final String message;
  final VoidCallback onGoToLogin;
  final String? code;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AuthErrorBanner(message: message, code: code),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: onGoToLogin,
                child: const Text(AppStrings.authSubmitLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
