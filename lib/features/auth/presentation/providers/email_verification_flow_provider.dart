import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the email-verification screen needs to exist, held in the state
/// layer rather than passed through `go_router`'s `extra`.
///
/// Same reasoning as `OtpFlowState` (ADR-0018 Amendment 2 A2-D2, applied
/// here by ADR-0021 D2): `extra` is JSON-encoded on its way into route
/// restoration state, and a `GoRouter.refresh()` while the user is on this
/// screen must not throw them out of the flow. [email] is not secret the
/// way `verificationId` is, but it is still the input this screen cannot
/// render without, so it goes through the same mechanism rather than a
/// route argument.
class EmailVerificationFlowState {
  const EmailVerificationFlowState({
    required this.email,
    required this.justSentEmail,
  });

  /// The Firebase account's email address, shown in the screen's subtitle.
  final String email;

  /// Whether *starting this flow* is itself the moment a verification email
  /// went out — true from `RegisterScreen` (which just called
  /// `sendEmailVerification` via `registerWithEmailPassword`), false from
  /// `LoginScreen`'s `OAUTH_EMAIL_NOT_VERIFIED` redirect (no email sent as
  /// part of that arrival). See `EmailVerificationScreen.justSentEmail` for
  /// why this has to travel with the flow rather than being decided at the
  /// screen.
  final bool justSentEmail;
}

/// Owns the email-verification flow's state for as long as the flow is open.
/// Mirrors [OtpFlowNotifier] — see that class for why clearing lives in a
/// `NavigatorObserver` (`EmailVerificationFlowObserver`) rather than
/// `State.dispose()` or `GoRoute.onExit`.
class EmailVerificationFlowNotifier
    extends Notifier<EmailVerificationFlowState?> {
  @override
  EmailVerificationFlowState? build() => null;

  /// Begins a flow, replacing whatever was there wholesale — same backstop
  /// reasoning as `OtpFlowNotifier.start`.
  void start(EmailVerificationFlowState flow) => state = flow;

  /// Ends the flow. Call from [EmailVerificationFlowObserver], not from a
  /// widget lifecycle callback (ADR-0018 Amendment 2 A2-D4's reasoning
  /// applies identically here).
  void clear() => state = null;
}

final NotifierProvider<
  EmailVerificationFlowNotifier,
  EmailVerificationFlowState?
>
emailVerificationFlowProvider =
    NotifierProvider<
      EmailVerificationFlowNotifier,
      EmailVerificationFlowState?
    >(EmailVerificationFlowNotifier.new);
