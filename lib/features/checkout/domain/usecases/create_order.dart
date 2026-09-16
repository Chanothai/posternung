import '../entities/order.dart';
import '../entities/shipping_address.dart';
import '../repositories/checkout_repository.dart';

/// Creates an order from an active reservation plus a shipping address. One
/// class, one action — see `ReserveListing` for the same shape.
class CreateOrder {
  CreateOrder(this._repository);
  final CheckoutRepository _repository;

  Future<Order> call({
    required String reservationId,
    required ShippingAddress shippingAddress,
  }) => _repository.createOrder(
    reservationId: reservationId,
    shippingAddress: shippingAddress,
  );
}
