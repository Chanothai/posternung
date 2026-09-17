/// Parses an HTTP `Date` header (RFC 7231 §7.1.1.1 IMF-fixdate, i.e. RFC
/// 1123 — `Wed, 16 Sep 2026 15:45:00 GMT`) into a UTC [DateTime].
///
/// Hand-written rather than `dart:io`'s `HttpDate.parse` on purpose: the
/// caller lives in `features/checkout/data/`, where `dart:io` is banned by
/// `test/core/no_local_persistence_test.dart` (NFR-02), and `package:
/// http_parser` is only a transitive dependency of `dio` — depending on it
/// directly would be a new library, which this repo doesn't add without
/// asking (root `CLAUDE.md`).
///
/// Returns `null` for anything that isn't a well-formed IMF-fixdate (a
/// missing header, the obsolete RFC 850/asctime forms, a non-`GMT` zone,
/// an out-of-range field) — never throws, because the only consumer uses
/// the value as an *optional* better anchor for the reservation countdown
/// and falls back when it's absent (`Reservation.countdownSpan`).
///
/// Pure Dart, no Flutter/`dart:io` imports — same rule as every file in
/// `core/utils/` (`lib/core/CLAUDE.md`).
DateTime? tryParseHttpDate(String? value) {
  if (value == null) return null;
  final RegExpMatch? m = _imfFixdate.firstMatch(value.trim());
  if (m == null) return null;

  final int day = int.parse(m.group(1)!);
  final int? month = _months[m.group(2)!.toLowerCase()];
  final int year = int.parse(m.group(3)!);
  final int hour = int.parse(m.group(4)!);
  final int minute = int.parse(m.group(5)!);
  final int second = int.parse(m.group(6)!);

  if (month == null) return null;
  if (day < 1 || day > 31) return null;
  if (hour > 23 || minute > 59 || second > 59) return null;

  final DateTime parsed = DateTime.utc(year, month, day, hour, minute, second);
  // `DateTime.utc` silently rolls an impossible date forward (31 Feb → 3
  // Mar); a header like that is malformed, not "close enough".
  if (parsed.month != month || parsed.day != day) return null;
  return parsed;
}

/// Optional weekday, then `DD Mon YYYY HH:MM:SS GMT`. Case-insensitive on
/// the alphabetic parts only — the numeric layout is fixed by the RFC.
final RegExp _imfFixdate = RegExp(
  r'^(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
  r'(\d{2}):(\d{2}):(\d{2})\s+GMT$',
  caseSensitive: false,
);

const Map<String, int> _months = <String, int>{
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};
