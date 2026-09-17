import 'backend_envelope.dart';

/// Domain-level exception for order/reservation failures (`SCR-07`). Same
/// three-field split as `AuthException`/`CatalogException` (ADR-0017 D1,
/// Amendment 1 A1-D1) — see `AuthException`'s doc comment for the mechanism
/// this class reuses unchanged: [displayMessage] is not a parameter of the
/// public constructor at all, only [OrderException.fromEnvelope] can set
/// it, and that constructor only accepts a [BackendErrorEnvelope] that can
/// only have come from `backendErrorEnvelopeOf`.
///
/// Adds five typed fields on top of that shared shape (ADR-0017 Amendment 2
/// A2-D2, `ADR-0037` Amendment 2 A2-D2, Amendment 5 A5-D4): on this
/// feature's two endpoints, every error code except `VALIDATION_ERROR`
/// sends `details[].message` as a bare machine value (ISO-8601, an integer,
/// a UUID, an order number) rather than prose —
/// [reservedUntil]/[expiredAt]/[limit]/[retryAfter]/[orderNo] are that
/// value, parsed and typed, picked out of [BackendErrorEnvelope.typedDetails]
/// by `field` name.
///
/// 🔴 **Nothing on this class's public surface exposes `typedDetails` or
/// the raw `details` string** — presentation may only ever see
/// [reservedUntil], [expiredAt], [limit], [retryAfter], [orderNo], and
/// [validationFields] (ADR-0017 Amendment 2 A2-D3/A2-D4, enforced by a
/// source scan in `test/core/error_message_safety_test.dart`). A typed
/// field that fails to parse is `null`, never a thrown error — presentation
/// falls back to [displayMessage] via the shared display-mapper's step 2
/// (`error_display.dart`'s allowlist algorithm), exactly like any other
/// missing value (ADR-0017 D4).
class OrderException implements Exception {
  const OrderException({required this.code, this.debugDetail})
    : displayMessage = null,
      reservedUntil = null,
      expiredAt = null,
      limit = null,
      retryAfter = null,
      orderNo = null,
      validationFields = const [];

  /// The only legal way to populate [displayMessage] and the five typed
  /// fields (ADR-0017 D2, Amendment 1 A1-D1, Amendment 2 A2-D2). [env] can
  /// only have come from `backendErrorEnvelopeOf`.
  ///
  /// Each typed field is looked up by `field` name in [env]'s
  /// `typedDetails` and parsed with `DateTime.tryParse`/`int.tryParse` — a
  /// row that is absent, or present but not parseable as that type, leaves
  /// the field `null` rather than throwing (ADR-0017 Amendment 2 A2-D2;
  /// this is the property the mutation test in `test/core/error/order_
  /// exception_test.dart` locks: a `reserved_until` row whose `message` is
  /// prose instead of an ISO-8601 string must yield `reservedUntil == null`,
  /// never a crash and never a mis-parsed value).
  OrderException.fromEnvelope(BackendErrorEnvelope env, {this.debugDetail})
    : code = env.code,
      displayMessage = env.displayMessage,
      reservedUntil = _dateTimeField(env, 'reserved_until'),
      expiredAt = _dateTimeField(env, 'expired_at'),
      limit = _intField(env, 'limit'),
      orderNo = _orderNoField(env, 'order_no'),
      retryAfter = env.retryAfterSeconds == null
          ? null
          : Duration(seconds: env.retryAfterSeconds!),
      validationFields = env.code == 'VALIDATION_ERROR'
          ? env.typedDetails
                .map((row) => _stripFieldPrefix(row.field))
                .toList(growable: false)
          : const [];

  final String code;
  final String? displayMessage;
  final String? debugDetail;

  /// From the `reserved_until` row of `details[]` on `POSTER_NOT_AVAILABLE`
  /// (reserve) — the poster being looked at is already held by someone
  /// else. `null` when the row is absent, unparseable, or this exception
  /// came from a different code entirely.
  final DateTime? reservedUntil;

  /// From the `expired_at` row of `details[]` on `RESERVATION_NOT_ACTIVE`.
  final DateTime? expiredAt;

  /// From the `limit` row of `details[]` on `RESERVATION_LIMIT_EXCEEDED`.
  final int? limit;

  /// From the `Retry-After` response header on a 429 — never from a
  /// `details` row (`ADR-0037` Amendment 2 A2-D2: a 429 sends
  /// `details: null`, the value travels in the header instead).
  final Duration? retryAfter;

  /// From the `order_no` row of `details[]` on `BUYER_HAS_LIVE_ORDER`
  /// (reserve, `ADR-0037` Amendment 5 A5-D4) — the poster being looked at
  /// already has a live order **of this buyer's own**, and this is its
  /// human-readable number (`PN-YYMMDD-NNNN`) for the screen to show.
  ///
  /// Validated against [_orderNoPattern] rather than taken as any string:
  /// unlike the other typed fields, this one is embedded verbatim into a
  /// Thai sentence the buyer reads (`AppStrings.checkoutErrorBuyerHasLive
  /// Order`), so a row that carried prose instead of the machine value
  /// would put backend prose on screen — exactly what ADR-0017 D3 forbids.
  /// A row that fails the pattern therefore degrades to `null` (the
  /// sentence then omits the number), the same "unparseable → null, never
  /// throw" rule the `DateTime`/`int` fields follow.
  final String? orderNo;

  /// `details[].field` names, populated only when [code] is
  /// `VALIDATION_ERROR` — for pointing at the offending form field. The
  /// corresponding `.message` values are English validator prose and are
  /// deliberately never exposed anywhere on this class (ADR-0017 D3); the
  /// text shown to the user for a validation failure comes from a static
  /// `AppStrings` constant instead, keyed off the field name.
  ///
  /// 🔴 F5 — stripped of any dotted prefix before landing here (via
  /// [_stripFieldPrefix]): `POST /orders`'s validator reports a nested
  /// field as `shipping_address.postal_code` (`posternung-backend/app/main.
  /// py`'s exception handler joins the pydantic error `loc` tuple with
  /// `.`), but `CheckoutAddressForm`'s `invalidFields.contains(...)` checks
  /// bare names (`'postal_code'`) — the two never matched before this fix,
  /// so a 422 on a nested address field highlighted nothing. `reservation_id`
  /// and every other bare (undotted) field name pass through unchanged.
  final List<String> validationFields;

  /// See [validationFields]'s doc comment (F5). Only the segment after the
  /// **last** `.` matters — a field with no `.` at all (e.g.
  /// `reservation_id`) is returned unchanged.
  static String _stripFieldPrefix(String field) {
    final int lastDot = field.lastIndexOf('.');
    return lastDot == -1 ? field : field.substring(lastDot + 1);
  }

  static DateTime? _dateTimeField(BackendErrorEnvelope env, String field) {
    for (final row in env.typedDetails) {
      if (row.field == field) return DateTime.tryParse(row.message);
    }
    return null;
  }

  static int? _intField(BackendErrorEnvelope env, String field) {
    for (final row in env.typedDetails) {
      if (row.field == field) return int.tryParse(row.message);
    }
    return null;
  }

  /// `PN-YYMMDD-NNNN` — `posternung-backend/app/repositories/order_
  /// repository.py` formats the running number with `:04d`, which is a
  /// **minimum** width, not a cap (its own comment: a 5-digit day still
  /// fits `String(20)`), hence `\d{4,}` rather than `\d{4}`. Anchored on
  /// both ends so a sentence that merely *contains* an order number is
  /// still rejected.
  static final RegExp _orderNoPattern = RegExp(r'^PN-\d{6}-\d{4,}$');

  static String? _orderNoField(BackendErrorEnvelope env, String field) {
    for (final row in env.typedDetails) {
      if (row.field == field) {
        return _orderNoPattern.hasMatch(row.message) ? row.message : null;
      }
    }
    return null;
  }

  @override
  String toString() => 'OrderException(code: $code)';
}
