/// What the OTP screen needs to exist, handed over as `GoRouter`'s `extra`
/// rather than through the URL.
///
/// ADR-0018 D6: `phoneNumber` is personal data, and `verificationId` /
/// `resendToken` are the values Firebase uses to confirm a phone credential —
/// none of them may appear in a path or a query string. `extra` is typed
/// `Object?`, and the repo declines `go_router_builder` (ADR-0018 D1), so
/// this class is the type: one object, cast in exactly one place
/// (`lib/core/router/app_router.dart`'s `/otp` builder), instead of three
/// loose values cast at each screen.
///
/// Known cost, not a surprise: `extra` is not serialised, so this is gone if
/// Android kills and restores the process mid-flow. That is not a regression
/// — the `MaterialPageRoute` this replaced lost it too — and the `/otp`
/// route's `redirect` turns the restored case into "land on home" rather
/// than a crash.
class OtpRouteArgs {
  const OtpRouteArgs({
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
  });

  /// E.164 number the code was texted to, e.g. `+66812345678`.
  final String phoneNumber;

  /// Firebase's verification ID for the code currently in flight.
  final String verificationId;

  /// Firebase's `forceResendingToken`; resend sends no second SMS without it.
  final int? resendToken;
}
