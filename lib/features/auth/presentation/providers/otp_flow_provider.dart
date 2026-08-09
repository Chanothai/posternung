import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the OTP screen needs to exist, held in the state layer rather than
/// handed to the route.
///
/// This used to be `OtpRouteArgs`, travelling as `GoRouter`'s `extra`
/// (ADR-0018 D6). **Amendment 2 moved it here**, and the rename is the
/// point: it is not a route argument any more, and a class still called
/// "route args" would invite the next person to put it back in `extra`.
///
/// Why it left `extra`: `extra` is round-tripped through
/// `RouteMatchListCodec`, which JSON-encodes it (`match.dart:893-908` of
/// go_router 17.4.0). A class JSON cannot encode becomes `null` — silently,
/// with only a `WARNING` log — so every `GoRouter.refresh()` dropped these
/// values and threw the user out of the middle of the flow. The `extraCodec`
/// that fixes that was rejected in Amendment 2 A2-D5: it would ship
/// [phoneNumber] and [verificationId] out of Dart into the platform's route
/// restoration state, which is the same class of exposure D6 keeps them off
/// the URL to avoid.
///
/// [verificationId] and [resendToken] still must not reach a path or a query
/// string (D6, unchanged) — and now they cannot, because the route carries
/// no arguments at all.
class OtpFlowState {
  const OtpFlowState({
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
  });

  /// E.164 number the code was texted to, e.g. `+66812345678`.
  final String phoneNumber;

  /// Firebase's verification ID for the code currently in flight. Replaced
  /// by [OtpFlowNotifier.codeResent] on every resend — this object is the
  /// only place it lives, so a resent code is verified against the SMS that
  /// was actually sent last.
  final String verificationId;

  /// Firebase's `forceResendingToken`; resend sends no second SMS without it.
  final int? resendToken;
}

/// Owns the phone-verification flow's state for as long as the flow is open.
///
/// Single source of truth on purpose: the OTP screen keeps no copy of
/// [OtpFlowState.verificationId]. Before Amendment 2 it did
/// (`_verificationId`, replaced locally on resend), and while that happened
/// to survive a rebuild, two copies of one value is drift waiting to happen.
class OtpFlowNotifier extends Notifier<OtpFlowState?> {
  @override
  OtpFlowState? build() => null;

  /// Begins a flow, replacing whatever was there **wholesale** rather than
  /// merging field by field.
  ///
  /// This is also the backstop for state that outlived its flow — a process
  /// restore, or an exit path nobody anticipated. Starting a new
  /// verification is the moment any leftover stops being reachable, so it is
  /// the moment to drop it.
  void start(OtpFlowState flow) => state = flow;

  /// Records the credentials of a **resent** SMS, keeping the phone number.
  ///
  /// A no-op when no flow is open: a resend that lands after the flow was
  /// abandoned must not resurrect it.
  void codeResent({required String verificationId, int? resendToken}) {
    final OtpFlowState? current = state;
    if (current == null) return;
    state = OtpFlowState(
      phoneNumber: current.phoneNumber,
      verificationId: verificationId,
      resendToken: resendToken,
    );
  }

  /// Ends the flow.
  ///
  /// 🔴 Call this from [OtpFlowObserver] — **not** from `State.dispose()` and
  /// **not** from `GoRoute.onExit`. Both of those also fire when
  /// `GoRouter.refresh()` merely rebuilds the route while the user is still
  /// standing on it (verified on go_router 17.4.0, Amendment 2 P-F), so
  /// clearing from either would delete the state that is in use and bounce
  /// the user out — the original bug with a new cause.
  void clear() => state = null;
}

final NotifierProvider<OtpFlowNotifier, OtpFlowState?> otpFlowProvider =
    NotifierProvider<OtpFlowNotifier, OtpFlowState?>(OtpFlowNotifier.new);
