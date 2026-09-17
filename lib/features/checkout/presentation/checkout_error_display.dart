import '../../../core/error/error_display.dart';
import '../../../core/error/order_exception.dart';
import '../../../core/strings/app_strings.dart';

/// The client-only code for "the countdown on `/checkout` reached zero"
/// (SCR-07 AC-11) — not a backend `error_code`. Synthesizing an
/// [OrderException] with this code lets `CheckoutReservationLost` render
/// through the exact same allowlist mapper as every backend-driven cause of
/// the same screen, instead of needing a second display path with no
/// `code` to key off. Lowercase/snake, matching the existing convention for
/// transport-level, non-backend codes (`network_error`/`server_error`).
const String kCheckoutCountdownExpiredCode = 'checkout_countdown_expired';

/// Maps an [OrderException] from `POST /orders` to a display message via
/// the shared three-step algorithm (ADR-0017 D4/D9 — see
/// `core/error/error_display.dart` for the algorithm; this file owns only
/// the two feature-specific tables step 1 reads).
///
/// Table source: `docs/status/gates/SCR-07-sliceB-gate1.md` §4 "orders".
String checkoutOrderErrorDisplayMessage(
  OrderException e, {
  required String fallback,
}) => resolveErrorDisplay(
  e.displayMessage,
  code: e.code,
  codeMessages: _ordersMessages(e),
  fallback: fallback,
).message;

Map<String, String> _ordersMessages(OrderException e) => {
  'RESERVATION_NOT_FOUND': AppStrings.checkoutErrorReservationNotFound,
  // Same code, two messages — chosen by whether `expired_at` parsed, not by
  // a second `error_code` (the contract deliberately reuses one code for
  // both "expired" and "already converted").
  'RESERVATION_NOT_ACTIVE': e.expiredAt != null
      ? AppStrings.checkoutErrorReservationExpired
      : AppStrings.checkoutErrorReservationUsed,
  'POSTER_NOT_AVAILABLE': AppStrings.checkoutErrorPosterGoneAtOrder,
  'VALIDATION_ERROR': AppStrings.checkoutErrorValidation,
  // The client-driven AC-11 path — see [kCheckoutCountdownExpiredCode].
  kCheckoutCountdownExpiredCode: AppStrings.checkoutErrorReservationExpired,
  // Transport-level codes thrown by CheckoutRemoteDataSource._guard /
  // CheckoutRepositoryImpl — not backend `error_code`s.
  'network_error': AppStrings.authErrorNetwork,
  'server_error': AppStrings.authErrorServer,
};

/// Maps an [OrderException] from `POST /listings/{poster_id}/reserve` to a
/// display message. Called from `poster/presentation/widgets/
/// poster_buy_now_button.dart`'s `_ReserveFailureNotice` (SCR-07 B3) — kept
/// in the same file as the orders table on purpose (see `checkout/
/// CLAUDE.md`'s note on this file having "two tables in one file"). Table
/// source: same gate document, §4 "reserve".
String reserveErrorDisplayMessage(
  OrderException e, {
  required String fallback,
}) => resolveErrorDisplay(
  e.displayMessage,
  code: e.code,
  codeMessages: _reserveMessages(e),
  fallback: fallback,
).message;

Map<String, String> _reserveMessages(OrderException e) {
  final Map<String, String> messages = {
    'BUYER_IS_SELLER': AppStrings.checkoutErrorBuyerIsSeller,
    'POSTER_ALREADY_RESERVED': AppStrings.checkoutErrorAlreadyReserved,
    // A5-D4 — the buyer's own live order on this poster. `orderNo` is
    // `null` when the row is missing/malformed; the string helper then
    // drops the parenthesised number rather than rendering "()".
    'BUYER_HAS_LIVE_ORDER': AppStrings.checkoutErrorBuyerHasLiveOrder(
      e.orderNo,
    ),
    'network_error': AppStrings.authErrorNetwork,
    'server_error': AppStrings.authErrorServer,
  };

  // F12 — `reserved_until` failing to parse does NOT fall through to
  // `displayMessage` (D4 step 2) for this code: it falls back to the static
  // `checkoutErrorPosterSoldOut` copy in the `else if` branch below instead,
  // because `POSTER_NOT_AVAILABLE` always gets a reserve-table entry one
  // way or the other once this function is reached for it — so step 2 of
  // the shared algorithm never actually triggers on this call site for this
  // code. The one thing this comment's first version got right: a message
  // naming a time it doesn't have must never be built, so the "with time"
  // wording below is still gated on `reservedUntil != null` specifically.
  if (e.reservedUntil != null) {
    messages['POSTER_NOT_AVAILABLE'] =
        '${AppStrings.checkoutErrorPosterReservedUntilPrefix}'
        '${_formatHHmm(e.reservedUntil!.toLocal())}'
        '${AppStrings.checkoutErrorPosterReservedUntilSuffix}';
  } else if (e.code == 'POSTER_NOT_AVAILABLE') {
    messages['POSTER_NOT_AVAILABLE'] = AppStrings.checkoutErrorPosterSoldOut;
  }

  if (e.limit != null) {
    messages['RESERVATION_LIMIT_EXCEEDED'] =
        '${AppStrings.checkoutErrorReservationLimitExceededPrefix}'
        '${e.limit}'
        '${AppStrings.checkoutErrorReservationLimitExceededSuffix}';
  }

  if (e.retryAfter != null) {
    messages['RESERVE_RATE_LIMITED'] =
        '${AppStrings.checkoutErrorRateLimitedPrefix}'
        '${e.retryAfter!.inSeconds}'
        '${AppStrings.checkoutErrorRateLimitedSuffix}';
  }

  return messages;
}

/// Hand-written `HH:mm`, local time — no `intl` in this project
/// (`pubspec.yaml`). [t] must already be `.toLocal()`d by the caller.
String _formatHHmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
