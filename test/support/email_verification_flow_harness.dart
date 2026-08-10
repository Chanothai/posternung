import 'package:posternung/features/auth/presentation/providers/email_verification_flow_provider.dart';

/// The real [EmailVerificationFlowNotifier] with a starting value, for tests
/// that need to arrive on `/verify-email` with a flow already open. Mirrors
/// `test/support/otp_flow_harness.dart`'s `SeededOtpFlow`.
class SeededEmailVerificationFlow extends EmailVerificationFlowNotifier {
  SeededEmailVerificationFlow(this.seed);

  final EmailVerificationFlowState? seed;

  @override
  EmailVerificationFlowState? build() => seed;
}
