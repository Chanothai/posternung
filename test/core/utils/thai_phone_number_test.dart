import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/utils/thai_phone_number.dart';

void main() {
  group('thaiMobileToE164', () {
    test('bare 9-digit form (matches the field\'s +66 prefix)', () {
      expect(thaiMobileToE164('812345678'), '+66812345678');
    });

    test('habitual leading-zero form', () {
      expect(thaiMobileToE164('0812345678'), '+66812345678');
    });

    test('leading-zero form with separators', () {
      expect(thaiMobileToE164('081-234-5678'), '+66812345678');
    });

    test('truncated leading-zero number (9 digits incl. the 0) is invalid', () {
      // The pre-fix formatter used to cap the field at 9 digits, which
      // truncated `0812345678` into `081234567` — this must not silently
      // "succeed" as a wrong number.
      expect(thaiMobileToE164('081234567'), isNull);
    });

    test('invalid leading digit after normalization', () {
      expect(thaiMobileToE164('0712345678'), isNull);
    });

    test('empty input', () {
      expect(thaiMobileToE164(''), isNull);
    });
  });
}
