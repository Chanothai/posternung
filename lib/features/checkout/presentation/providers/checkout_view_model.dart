import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/order_exception.dart';
import '../../domain/entities/shipping_address.dart';
import '../checkout_error_display.dart';
import '../state/checkout_state.dart';
import 'checkout_flow_provider.dart';
import 'checkout_providers.dart';
import 'reservation_countdown_provider.dart';

/// `/checkout`'s ViewModel (root `CLAUDE.md`'s MVI-style state, reserved for
/// cart/checkout). `submit()` calls `CreateOrder`, never
/// `CheckoutRepository` directly.
///
/// Listens to [reservationCountdownProvider] (GATE 1 §2) rather than owning
/// a `Timer` itself — see that provider's doc comment for why the countdown
/// is split out. A tick that reaches [Duration.zero] transitions
/// [CheckoutReady]/[CheckoutFailed] to [CheckoutReservationLost] (AC-11);
/// [CheckoutSubmitting]/[CheckoutReservationLost]/[CheckoutOrderCreated] are
/// left alone — the backend, not the client clock, is what decides an
/// in-flight submit, and the two terminal states must not receive another
/// event at all.
class CheckoutViewModel extends Notifier<CheckoutState> {
  @override
  CheckoutState build() {
    ref.listen<Duration>(reservationCountdownProvider, (
      Duration? previous,
      Duration next,
    ) {
      if (next == Duration.zero) _onCountdownExpired();
    });
    return const CheckoutReady();
  }

  void _onCountdownExpired() {
    // `reservationCountdownProvider` also reaches `Duration.zero` when
    // `checkoutFlowProvider` is *cleared* — `CheckoutFlowObserver.didPop`
    // does exactly that on the way out of `/checkout`, and the countdown's
    // `build()` returns `Duration.zero` immediately for a null flow rather
    // than winding down through 1-second ticks. That is a departure, not an
    // expiry: without this guard, popping (or going home) out of a
    // `CheckoutReady`/`CheckoutFailed` screen flashed
    // `CheckoutReservationLost` for one frame during the pop, and — because
    // this provider was not `autoDispose` (F1) — the stale state used to
    // survive to the *next* checkout flow too.
    if (ref.read(checkoutFlowProvider) == null) return;
    if (state is CheckoutReady || state is CheckoutFailed) {
      state = const CheckoutReservationLost(
        OrderException(code: kCheckoutCountdownExpiredCode),
      );
    }
  }

  /// Submits the order. A no-op if called from a terminal state
  /// ([CheckoutOrderCreated]/[CheckoutReservationLost]) or with no flow open
  /// — the screen disables the form in both cases, this is the backstop.
  Future<void> submit(ShippingAddress address) async {
    if (state is CheckoutOrderCreated || state is CheckoutReservationLost) {
      return;
    }
    final CheckoutFlowState? flow = ref.read(checkoutFlowProvider);
    if (flow == null) return;

    state = const CheckoutSubmitting();
    try {
      final order = await ref
          .read(createOrderProvider)
          .call(reservationId: flow.reservation.id, shippingAddress: address);
      state = CheckoutOrderCreated(order);
    } on OrderException catch (e) {
      state = _reservationLostCodes.contains(e.code)
          ? CheckoutReservationLost(e)
          : CheckoutFailed(e);
    }
  }
}

/// `POST /orders` codes that mean the reservation this checkout was built
/// on is gone (AC-4) — table source: gate document §4 "orders".
const Set<String> _reservationLostCodes = {
  'RESERVATION_NOT_FOUND',
  'RESERVATION_NOT_ACTIVE',
  'POSTER_NOT_AVAILABLE',
};

/// `autoDispose` (F1 — was a plain `NotifierProvider` before, which in
/// Riverpod 3.3.2 is **not** auto-disposing by default:
/// `NotifierProvider(...)` sets `isAutoDispose = false` unless built through
/// `NotifierProvider.autoDispose` specifically —
/// `riverpod-3.3.2/lib/src/providers/notifier/orphan.dart:86`). Without this,
/// this notifier's state (e.g. `CheckoutOrderCreated`/`CheckoutReservationLost`)
/// survived after the user left `/checkout` entirely, so the *next* reservation
/// re-entered on a stale terminal state instead of a fresh `CheckoutReady`.
final NotifierProvider<CheckoutViewModel, CheckoutState>
checkoutViewModelProvider =
    NotifierProvider.autoDispose<CheckoutViewModel, CheckoutState>(
      CheckoutViewModel.new,
    );
