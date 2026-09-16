import 'package:posternung/features/checkout/presentation/providers/checkout_flow_provider.dart';

/// The real [CheckoutFlowNotifier] with a starting value, for tests that
/// need to arrive on `/checkout` (or just render `CheckoutScreen` directly)
/// with a flow already open.
///
/// Subclassed rather than faked on purpose — same reasoning as
/// `SeededOtpFlow` (`otp_flow_harness.dart`): `start`/`clear` stay the
/// production implementation.
///
/// Used as `checkoutFlowProvider.overrideWith(() => SeededCheckoutFlow(...))`
/// at each call site.
class SeededCheckoutFlow extends CheckoutFlowNotifier {
  SeededCheckoutFlow(this.seed);

  final CheckoutFlowState? seed;

  @override
  CheckoutFlowState? build() => seed;
}
