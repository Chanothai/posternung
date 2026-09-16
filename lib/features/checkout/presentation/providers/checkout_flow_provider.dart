import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../poster/domain/entities/poster_detail.dart';
import '../../domain/entities/reservation.dart';

/// What `/checkout` needs to exist, held in the state layer rather than
/// handed to the route (`ADR-0018` Amendment 2 A2-D2 — same shape as
/// `OtpFlowState`/`EmailVerificationFlowState`).
///
/// Carries the [reservation] the buyer just made plus a [posterSnapshot] of
/// the listing SCR-05 already loaded, so the checkout screen never has to
/// issue its own `GET /posters/{id}` just to show a title/price/image.
/// 🔴 Deliberately carries **no shipping address field** (SCR-07 AC-2) — the
/// form's values live only in the screen's own `TextEditingController`s.
class CheckoutFlowState {
  /// [stopwatch] is a test-only seam — production call sites never pass it,
  /// so every real flow gets a genuine, already-running `Stopwatch`. Tests
  /// pass a fake (e.g. a `Stopwatch` subclass overriding `elapsed`) because
  /// `flutter_test`'s fake-async clock (`tester.pump(Duration)`) virtualizes
  /// `Timer`, but **not** `Stopwatch.elapsed` — that reads real wall-clock
  /// ticks regardless of which `Zone` it runs in, so a test that needs to
  /// advance the countdown deterministically has to control this value
  /// directly rather than relying on `tester.pump` to move it.
  CheckoutFlowState({
    required this.reservation,
    required this.posterSnapshot,
    Stopwatch? stopwatch,
  }) : stopwatch = stopwatch ?? (Stopwatch()..start());

  final Reservation reservation;
  final PosterDetail posterSnapshot;

  /// Started the instant this flow began — i.e. the moment the reservation
  /// response was received, not whenever `/checkout` happens to build.
  /// `reservationCountdownProvider` computes remaining time as
  /// `(expiresAt - createdAt) - stopwatch.elapsed`, anchored here rather
  /// than on repeated `DateTime.now()` reads (GATE 1 §6 item 5 — the same
  /// reasoning `StartupTrace` uses elsewhere in this app).
  final Stopwatch stopwatch;
}

/// Owns the checkout flow's state for as long as `/checkout` is open. Same
/// "start() overwrites wholesale, clear() only from the observer" shape as
/// `OtpFlowNotifier` — see that class's doc comment for why `clear()` must
/// be called from `CheckoutFlowObserver.didPop` and not from
/// `State.dispose()`/`GoRoute.onExit` (both also fire on a
/// `GoRouter.refresh()` that never left the route).
class CheckoutFlowNotifier extends Notifier<CheckoutFlowState?> {
  @override
  CheckoutFlowState? build() => null;

  void start(CheckoutFlowState flow) => state = flow;

  void clear() => state = null;
}

final NotifierProvider<CheckoutFlowNotifier, CheckoutFlowState?>
checkoutFlowProvider =
    NotifierProvider<CheckoutFlowNotifier, CheckoutFlowState?>(
      CheckoutFlowNotifier.new,
    );
