import 'order_status.dart';

/// A created order (`POST /orders` → `OrderResponse`, SCR-07). Plain, no
/// Flutter/serialization imports — see `data/models/order_model.dart` for
/// the DTO.
///
/// 🔴 Deliberately carries **no shipping address field** — `OrderResponse`
/// itself omits it (`ADR-0020` D5 ชั้น ก: the buyer just typed it, echoing
/// it back only creates another place PII can leak) and this entity must
/// not invent one.
class Order {
  const Order({
    required this.id,
    required this.orderNo,
    required this.posterId,
    required this.status,
    required this.itemPrice,
    required this.shippingFee,
    required this.totalAmount,
    required this.itemTitle,
    required this.createdAt,
  });

  final String id;

  /// Human-readable order number (`PN-YYMMDD-NNNN`) — what
  /// `OrderCreatedView` shows the buyer, not [id].
  final String orderNo;

  final String posterId;

  /// `null` when the backend sends a status this build doesn't recognize —
  /// see `orderStatusFromApi`. Never thrown on.
  final OrderStatus? status;

  /// Decimal-as-string, exactly as the backend sends it — same reasoning as
  /// `PosterDetail.price` (avoids float precision loss on money).
  final String itemPrice;

  /// `0` for every listing in Closed Beta (mission decided 2026-09-15) —
  /// still a real field, not a placeholder for "not filled in yet".
  final String shippingFee;

  /// `item_price + shipping_fee`, computed and CHECK-constrained server
  /// side.
  final String totalAmount;

  /// Snapshot of the listing's title at order time — the seller may have
  /// since edited the listing itself.
  final String itemTitle;

  final DateTime createdAt;
}
