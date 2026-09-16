/// An order's lifecycle status (`posternung-backend`'s `OrderStatus` enum —
/// `docs/api/openapi.yaml`, all 8 values a buyer's own order can be in,
/// decided 2026-09-15: every status the *buyer's* order can be in, not just
/// the ones Beta's UI has a path to).
///
/// 🔴 [disputed] and [refunded] have **no reachable path in Closed Beta**
/// (`ADR-0035` OD-2 — no dispute intake, no "แจ้งปัญหา" button). They are
/// declared anyway because the wire enum has 8 values and an order response
/// carrying one of them must not crash this client — see
/// `orderStatusFromApi`. Do not build any affordance that suggests a buyer
/// can reach these from here.
enum OrderStatus {
  awaitingPayment,
  paymentReview,
  awaitingShipment,
  shipped,
  completed,
  cancelled,
  disputed,
  refunded,
}

/// Parses the backend's `status` wire value, returning `null` for anything
/// this client doesn't recognize — same convention as
/// `PosterSummaryModel.toEntity` (`poster_status.dart`), not
/// `PosterDetailModel.toEntity`'s throw: an order the buyer is looking at
/// right after `POST /orders` succeeds should still render (order number,
/// "awaiting payment" banner) even if a future backend status this build
/// has never heard of shows up — throwing would take the whole
/// `OrderCreated` screen down over a status label.
OrderStatus? orderStatusFromApi(String value) => switch (value) {
  'AWAITING_PAYMENT' => OrderStatus.awaitingPayment,
  'PAYMENT_REVIEW' => OrderStatus.paymentReview,
  'AWAITING_SHIPMENT' => OrderStatus.awaitingShipment,
  'SHIPPED' => OrderStatus.shipped,
  'COMPLETED' => OrderStatus.completed,
  'CANCELLED' => OrderStatus.cancelled,
  'DISPUTED' => OrderStatus.disputed,
  'REFUNDED' => OrderStatus.refunded,
  _ => null,
};
