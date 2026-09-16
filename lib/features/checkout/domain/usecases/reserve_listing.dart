import '../entities/reservation.dart';
import '../repositories/checkout_repository.dart';

/// Reserves one poster for the current user. One class, one action — see
/// `SignOut` (`features/auth/domain/usecases/sign_out.dart`) for the same
/// shape.
///
/// 🔴 Callers must **not** gate this on a poster's `status` (SCR-07 AC-15) —
/// the backend is the sole judge of whether a reservation succeeds, because
/// it is also the only thing that can lazy-expire a stale reservation
/// (`ADR-0033` D4). Call it whenever the buyer taps "ซื้อเลย", every time.
class ReserveListing {
  ReserveListing(this._repository);
  final CheckoutRepository _repository;

  Future<Reservation> call(String posterId) =>
      _repository.reserveListing(posterId);
}
