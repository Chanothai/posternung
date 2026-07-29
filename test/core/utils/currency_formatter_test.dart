import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/utils/currency_formatter.dart';

void main() {
  group('formatThbPrice', () {
    test('formats a plain decimal-as-string price as Baht', () {
      expect(formatThbPrice('450.00'), '฿450.00');
    });

    test('adds thousands separators for large amounts', () {
      expect(formatThbPrice('12500.5'), '฿12,500.50');
    });

    test('zero price', () {
      expect(formatThbPrice('0.00'), '฿0.00');
    });

    test('integer-only string still gets two decimal places', () {
      expect(formatThbPrice('620'), '฿620.00');
    });

    test('null price falls back rather than crashing', () {
      expect(formatThbPrice(null), '฿-');
    });

    test('empty string falls back rather than crashing', () {
      expect(formatThbPrice(''), '฿-');
    });

    test('malformed price falls back rather than crashing', () {
      expect(formatThbPrice('not-a-number'), '฿-');
    });

    test('custom fallback is honored', () {
      expect(formatThbPrice(null, fallback: 'N/A'), 'N/A');
    });
  });
}
