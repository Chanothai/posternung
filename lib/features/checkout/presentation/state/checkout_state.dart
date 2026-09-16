import '../../../../core/error/order_exception.dart';
import '../../domain/entities/order.dart';

/// `/checkout`'s MVI-style state (root `CLAUDE.md`'s "reserve this shape for
/// cart/checkout" — this is the first feature to actually use it). A
/// `sealed class` so `CheckoutScreen`'s `switch` over it is exhaustive —
/// the analyzer fails the build if a case is ever added here and missed
/// there.
///
/// 🔴 **No subclass holds a shipping address** (SCR-07 AC-2) — the form's
/// values live only in the screen's own `TextEditingController`s, so
/// leaving `/checkout` after a failed submit and coming back always starts
/// from an empty form.
sealed class CheckoutState {
  const CheckoutState();
}

/// Reservation active, countdown running, form open for editing. Both the
/// initial state and where a retry from [CheckoutFailed] returns to.
class CheckoutReady extends CheckoutState {
  const CheckoutReady();
}

/// `POST /orders` is in flight. The countdown hitting zero while here must
/// **not** transition anything — the backend, not the client clock, decides
/// whether the in-flight request still succeeds (same principle as AC-15).
class CheckoutSubmitting extends CheckoutState {
  const CheckoutSubmitting();
}

/// A retryable failure — 422 validation or a transport error. The form is
/// still on screen and the countdown keeps running.
class CheckoutFailed extends CheckoutState {
  const CheckoutFailed(this.exception);
  final OrderException exception;
}

/// The reservation is gone — expired locally (AC-11), or the backend said
/// so (`RESERVATION_NOT_FOUND` / `RESERVATION_NOT_ACTIVE` /
/// `POSTER_NOT_AVAILABLE`, AC-4). Terminal: nothing transitions out of this
/// except leaving the screen.
///
/// [exception] is always populated, even for the client-driven timeout —
/// see `kCheckoutCountdownExpiredCode` — so both paths render through the
/// exact same allowlist mapper (`checkout_error_display.dart`) instead of
/// one of the two paths needing its own separate message plumbing.
class CheckoutReservationLost extends CheckoutState {
  const CheckoutReservationLost(this.exception);
  final OrderException exception;
}

/// `POST /orders` succeeded. Terminal — nothing transitions out of this
/// except leaving the screen. Rendered in place (A4-D1), never routed
/// anywhere else.
class CheckoutOrderCreated extends CheckoutState {
  const CheckoutOrderCreated(this.order);
  final Order order;
}
