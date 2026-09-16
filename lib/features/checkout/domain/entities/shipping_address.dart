/// The address a buyer types at checkout — matches `ShippingAddressInput`
/// (`docs/api/openapi.yaml`) field for field, which itself matches the
/// `order_shipping_details` table (`ADR-0020` D5 · D12.1).
///
/// 🔴 This is personal data (`ADR-0020` D9) — nothing in this feature may
/// persist it locally (AC-2) or log it (AC-7); see
/// `test/features/checkout/no_local_persistence_test.dart` (B6, out of this
/// slice) for the source scan that guards that.
class ShippingAddress {
  const ShippingAddress({
    required this.recipientName,
    required this.recipientPhone,
    required this.addressLine,
    this.subDistrict,
    this.district,
    required this.province,
    required this.postalCode,
  });

  /// Required, 1-120 chars (`ShippingAddressInput.recipient_name`).
  final String recipientName;

  /// Required, 1-20 chars.
  final String recipientPhone;

  /// Required, min length 1 — no `maxLength` on the contract.
  final String addressLine;

  /// Optional, max 80 chars.
  final String? subDistrict;

  /// Optional, max 80 chars.
  final String? district;

  /// Required, 1-80 chars.
  final String province;

  /// Required, 1-10 chars.
  final String postalCode;
}
