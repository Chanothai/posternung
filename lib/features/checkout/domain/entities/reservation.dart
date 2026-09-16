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
}
