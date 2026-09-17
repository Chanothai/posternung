import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'checkout_flow_provider.dart';

// This is a plain `NotifierProvider`, not `.autoDispose` — it doesn't need
// to be. `build()` re-runs on every `checkoutFlowProvider` change (it's
// `ref.watch`ed, not `ref.read`), and when the flow is cleared the `if (flow
// == null)` branch above cancels `_timer` and returns `Duration.zero`
// itself. The countdown stops the moment `/checkout`'s flow ends regardless
// of whether anything is still watching this provider, so there's no
// leaked `Timer` for `.autoDispose` to clean up.

/// The single source of the countdown shown (pinned) on `/checkout` (SCR-07
/// AC-8/AC-11).
///
/// Split out from `CheckoutViewModel`'s state on purpose (GATE 1 §2): if the
/// remaining time lived in the same sealed state as the rest of the screen,
/// every tick would rebuild the whole form the buyer is typing into.
///
/// 🔴 There is no `60` (minutes or otherwise) anywhere in this file — the
/// remaining time is `reservation.countdownSpan - stopwatch.elapsed`, i.e.
/// the **server's own span** for this reservation, anchored on the
/// `Stopwatch` `CheckoutFlowState` started the moment the reservation was
/// received (AC-8: "ค่าอ่านจาก config ห้าม hardcode" — this goes one step
/// further and never even materializes the config value client-side).
/// `countdownSpan` is `expiresAt - serverReceivedAt` (the response's `Date`
/// header) when available, so a **200** replay of an older reservation
/// (A5-D1) starts from what is actually left, not from the full TTL —
/// see `Reservation.countdownSpan` (code-critic 2026-09-17, F-Med).
class ReservationCountdownNotifier extends Notifier<Duration> {
  Timer? _timer;
  Duration _span = Duration.zero;
  Stopwatch? _stopwatch;

  @override
  Duration build() {
    ref.onDispose(() {
      _timer?.cancel();
    });

    final CheckoutFlowState? flow = ref.watch(checkoutFlowProvider);
    _timer?.cancel();
    _timer = null;

    if (flow == null) {
      _stopwatch = null;
      return Duration.zero;
    }

    _span = flow.reservation.countdownSpan;
    _stopwatch = flow.stopwatch;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    return _remaining();
  }

  Duration _remaining() {
    final Stopwatch? stopwatch = _stopwatch;
    if (stopwatch == null) return Duration.zero;
    final Duration remaining = _span - stopwatch.elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _tick() {
    final Duration remaining = _remaining();
    state = remaining;
    if (remaining == Duration.zero) {
      _timer?.cancel();
    }
  }
}

final NotifierProvider<ReservationCountdownNotifier, Duration>
reservationCountdownProvider =
    NotifierProvider<ReservationCountdownNotifier, Duration>(
      ReservationCountdownNotifier.new,
    );
