/// Converts a Thai mobile number typed in national form into E.164.
///
/// Accepts both the bare 9-digit form the login field's `+66 ` prefix
/// expects (`812345678`) and the habitual form people actually type,
/// including the leading `0` (`0812345678`), with or without separators
/// (`081-234-5678`). Returns `null` when [input] isn't a valid Thai mobile
/// number (wrong length, or doesn't start with 6/8/9 after normalization).
String? thaiMobileToE164(String input) {
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length != 9) return null;
  if (!RegExp(r'^[689]').hasMatch(digits)) return null;
  return '+66$digits';
}
