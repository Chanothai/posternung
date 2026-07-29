/// Formats a poster price for display as Thai Baht.
///
/// `posternung-backend` sends `price` as a decimal-as-string (e.g.
/// `"450.00"`, see `PosterDetail.price`) rather than a `double`, to avoid
/// floating-point precision loss on a monetary value — this function keeps
/// that string-in, string-out shape and only formats for display, it never
/// round-trips through a `double` for arithmetic. The only payment method
/// today is PromptPay (ADR-0002) settling in Thai Baht, so every price
/// shown anywhere in the app must read `฿`, never `$`.
///
/// Every poster-listing screen (SCR-03/04/05/06) shows a price, so this
/// lives in `core/utils/` to be shared rather than reimplemented per
/// screen. Parses with `num.tryParse` — a `null`/empty/malformed [price]
/// (should never happen against a well-formed backend response, but must
/// not crash a UI) falls back to [fallback] instead of throwing.
String formatThbPrice(String? price, {String fallback = '฿-'}) {
  if (price == null || price.isEmpty) return fallback;
  final parsed = num.tryParse(price);
  if (parsed == null) return fallback;

  final fixed = parsed.toStringAsFixed(2);
  final dotIndex = fixed.indexOf('.');
  final wholePart = fixed.substring(0, dotIndex);
  final decimalPart = fixed.substring(dotIndex);

  final isNegative = wholePart.startsWith('-');
  final digits = isNegative ? wholePart.substring(1) : wholePart;

  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  final sign = isNegative ? '-' : '';
  return '฿$sign$buffer$decimalPart';
}
