/// A poster held for the current user (`POST /listings/{poster_id}/reserve`
/// → `ReservationResponse`, SCR-07). Plain, no Flutter/serialization
/// imports — see `data/models/reservation_model.dart` for the DTO.
///
/// Deliberately narrower than the wire response: `user_id`/`status` aren't
/// carried here because nothing in this feature reads them — the reservation
/// is always the caller's own (401/404 otherwise) and is always `active` the
/// moment this entity is constructed (`ADR-0037` GATE 1 §2).
class Reservation {
  const Reservation({
    required this.id,
    required this.posterId,
    required this.expiresAt,
    required this.createdAt,
    this.serverReceivedAt,
  });

  final String id;
  final String posterId;

  /// TTL end (`platform_settings.reservation_ttl_minutes` — 60 minutes,
  /// `ADR-0030` D3). Combined with [createdAt] this gives the *server's*
  /// span for the countdown — see `reservationCountdownProvider`, which
  /// anchors on a `Stopwatch` started the moment this reservation was
  /// received rather than on `DateTime.now()` (GATE 1 §6 item 5).
  final DateTime expiresAt;

  final DateTime createdAt;

  /// The server's own clock at the moment it answered — the response's
  /// `Date` header, parsed in the data source. `null` when the header was
  /// absent or malformed.
  ///
  /// Why it exists (code-critic 2026-09-17, F-Med): a **200** replay of the
  /// buyer's *existing* reservation (`ADR-0037` A5-D1) carries the original
  /// `created_at`, so `expiresAt - createdAt` is the row's *full* TTL, not
  /// what is left of it — a 45-minute-old reservation replayed as 200 would
  /// count down from 59:59 with 15:00 actually remaining (SCR-07 AC-8). The
  /// server's now is the only clock that can be trusted against
  /// `expiresAt` (GATE 1 §6 item 5 — never the device's `DateTime.now()`),
  /// and `Date` is the one place a response already carries it without a
  /// contract change.
  final DateTime? serverReceivedAt;

  /// How long this reservation had left **at the moment the response was
  /// received** — the span `reservationCountdownProvider` counts down from,
  /// anchored on the `Stopwatch` `CheckoutFlowState` starts at that same
  /// moment.
  ///
  /// `expiresAt - serverReceivedAt` when the server told us its now;
  /// otherwise `expiresAt - createdAt`, which is exact for a **201** (a row
  /// created in this very response) and the pre-A5 behaviour for everything
  /// else. 🔴 The fallback is deliberately `createdAt`, never
  /// `DateTime.now()`.
  Duration get countdownSpan =>
      expiresAt.difference(serverReceivedAt ?? createdAt);
}
