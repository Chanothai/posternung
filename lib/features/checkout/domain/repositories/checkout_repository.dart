import '../entities/order.dart';
import '../entities/reservation.dart';
import '../entities/shipping_address.dart';

/// Reservation + order operations (SCR-07). Implementations must throw
/// `OrderException` (`core/error/order_exception.dart`) on failure — never a
/// package-specific exception type — same convention as
/// `AuthRepository`/`PosterRepository`.
abstract class CheckoutRepository {
  /// `POST /listings/{poster_id}/reserve` — the "ซื้อเลย" button. No request
  /// body by contract: the buyer comes from the auth token and the clock
  /// from the server (`ADR-0037` GATE 1 §3 item 2 · security-baseline §4).
  Future<Reservation> reserveListing(String posterId);

  /// `POST /orders` — creates an order from a still-`active` reservation
  /// plus the shipping address the buyer just typed.
  Future<Order> createOrder({
    required String reservationId,
    required ShippingAddress shippingAddress,
  });
}
