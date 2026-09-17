import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/utils/http_date.dart';

void main() {
  group('tryParseHttpDate', () {
    test('parses an IMF-fixdate (RFC 1123) into the exact UTC instant', () {
      expect(
        tryParseHttpDate('Wed, 16 Sep 2026 15:45:07 GMT'),
        DateTime.utc(2026, 9, 16, 15, 45, 7),
      );
    });

    test('the result is UTC, not local', () {
      expect(tryParseHttpDate('Wed, 16 Sep 2026 15:45:07 GMT')!.isUtc, isTrue);
    });

    test('tolerates a missing weekday and surrounding whitespace', () {
      expect(
        tryParseHttpDate('  16 Sep 2026 15:45:07 GMT '),
        DateTime.utc(2026, 9, 16, 15, 45, 7),
      );
    });

    test('every month abbreviation maps to its own number (closed world: '
        'Jan..Dec → 1..12, no two names on the same month)', () {
      const names = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final months = <int>[];
      for (final name in names) {
        months.add(tryParseHttpDate('01 $name 2026 00:00:00 GMT')!.month);
      }
      expect(months, List<int>.generate(12, (i) => i + 1));
    });

    test('returns null (never throws) for null / empty / garbage', () {
      expect(tryParseHttpDate(null), isNull);
      expect(tryParseHttpDate(''), isNull);
      expect(tryParseHttpDate('not a date'), isNull);
      expect(tryParseHttpDate('2026-09-16T15:45:07Z'), isNull);
    });

    test('returns null for the obsolete RFC 850 and asctime forms rather '
        'than half-parsing them', () {
      expect(tryParseHttpDate('Wednesday, 16-Sep-26 15:45:07 GMT'), isNull);
      expect(tryParseHttpDate('Wed Sep 16 15:45:07 2026'), isNull);
    });

    test('returns null for a non-GMT zone — the RFC only allows GMT and a '
        'numeric offset would silently shift the anchor', () {
      expect(tryParseHttpDate('Wed, 16 Sep 2026 15:45:07 +0700'), isNull);
      expect(tryParseHttpDate('Wed, 16 Sep 2026 15:45:07 UTC'), isNull);
    });

    test('returns null for an unknown month name or out-of-range field '
        'instead of rolling the date forward', () {
      expect(tryParseHttpDate('Wed, 16 Foo 2026 15:45:07 GMT'), isNull);
      expect(tryParseHttpDate('Wed, 31 Feb 2026 15:45:07 GMT'), isNull);
      expect(tryParseHttpDate('Wed, 16 Sep 2026 24:00:00 GMT'), isNull);
      expect(tryParseHttpDate('Wed, 16 Sep 2026 15:60:00 GMT'), isNull);
    });
  });
}
