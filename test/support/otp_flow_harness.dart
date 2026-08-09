import 'package:posternung/features/auth/presentation/providers/otp_flow_provider.dart';

/// The real [OtpFlowNotifier] with a starting value, for tests that need to
/// arrive on `/otp` with a flow already open.
///
/// Subclassed rather than faked on purpose: `start`, `codeResent` and
/// `clear` stay the production implementations, so a test that asserts the
/// flow is cleared on the way out — or *not* cleared on a
/// `GoRouter.refresh()` — is exercising the code that ships.
///
/// Used as `otpFlowProvider.overrideWith(() => SeededOtpFlow(...))` at each
/// call site; Riverpod 3 does not export the `Override` type, so there is no
/// helper that returns one.
class SeededOtpFlow extends OtpFlowNotifier {
  SeededOtpFlow(this.seed);

  final OtpFlowState? seed;

  @override
  OtpFlowState? build() => seed;
}
