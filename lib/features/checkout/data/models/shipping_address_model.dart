import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/shipping_address.dart';

part 'shipping_address_model.freezed.dart';

/// Outbound-only DTO for `ShippingAddressInput` — there is no
/// `fromJson`/`.g.dart` here on purpose: this app never *receives* a
/// shipping address back from the backend (`OrderResponse` omits it
/// entirely, `ADR-0020` D5 ชั้น ก), so the only direction this model ever
/// travels is [fromEntity] → [toJson].
@freezed
abstract class ShippingAddressModel with _$ShippingAddressModel {
  const ShippingAddressModel._();

  const factory ShippingAddressModel({
    required String recipientName,
    required String recipientPhone,
    required String addressLine,
    String? subDistrict,
    String? district,
    required String province,
    required String postalCode,
  }) = _ShippingAddressModel;

  factory ShippingAddressModel.fromEntity(ShippingAddress address) =>
      ShippingAddressModel(
        recipientName: address.recipientName,
        recipientPhone: address.recipientPhone,
        addressLine: address.addressLine,
        subDistrict: address.subDistrict,
        district: address.district,
        province: address.province,
        postalCode: address.postalCode,
      );

  /// Hand-written, snake_case, matching `ShippingAddressInput` field for
  /// field — no `json_serializable` codegen for a shape this small that
  /// only ever goes one direction.
  Map<String, dynamic> toJson() => {
    'recipient_name': recipientName,
    'recipient_phone': recipientPhone,
    'address_line': addressLine,
    'sub_district': subDistrict,
    'district': district,
    'province': province,
    'postal_code': postalCode,
  };
}
