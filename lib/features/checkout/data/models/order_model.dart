import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';

part 'order_model.freezed.dart';
part 'order_model.g.dart';

/// DTO for the backend's `OrderResponse` (`POST /orders`). `status` is
/// decoded as a raw `String` here (not `@JsonEnum`) — same convention as
/// `PosterDetailModel.status` (`poster_detail_model.dart`) — so
/// [toEntity] can map it via `orderStatusFromApi` and degrade an
/// unrecognized/future value to `null` instead of `fromJson` crashing with
/// a bare `TypeError`.
///
/// Every field below was checked field-by-field against
/// `OrderResponse` in `docs/api/openapi.yaml` (not assumed from the name
/// matching) — `item_price`/`shipping_fee`/`total_amount` are `string`
/// (`format: decimal`) on the wire, never `number` (the exact class of bug
/// `poster-database`/SCR-05's `price` comment warns about), so they stay
/// `String` end-to-end here too.
@freezed
abstract class OrderModel with _$OrderModel {
  const OrderModel._();

  const factory OrderModel({
    required String id,
    @JsonKey(name: 'order_no') required String orderNo,
    @JsonKey(name: 'poster_id') required String posterId,
    required String status,
    @JsonKey(name: 'item_price') required String itemPrice,
    @JsonKey(name: 'shipping_fee') required String shippingFee,
    @JsonKey(name: 'total_amount') required String totalAmount,
    @JsonKey(name: 'item_title') required String itemTitle,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _OrderModel;

  factory OrderModel.fromJson(Map<String, dynamic> json) =>
      _$OrderModelFromJson(json);

  /// Never throws on an unrecognized `status` — see `orderStatusFromApi`'s
  /// doc comment for why this endpoint degrades instead of failing loudly
  /// the way `PosterDetailModel.toEntity` does.
  Order toEntity() => Order(
    id: id,
    orderNo: orderNo,
    posterId: posterId,
    status: orderStatusFromApi(status),
    itemPrice: itemPrice,
    shippingFee: shippingFee,
    totalAmount: totalAmount,
    itemTitle: itemTitle,
    createdAt: createdAt,
  );
}
