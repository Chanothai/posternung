import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/error/order_exception.dart';

import '../../support/backend_envelope_fixture.dart';

void main() {
  group('OrderException (default constructor)', () {
    test('leaves every optional field null/empty when constructed directly '
        '(ADR-0017 D1 — the only way to populate them is fromEnvelope)', () {
      const exception = OrderException(code: 'unexpected');

      expect(exception.code, 'unexpected');
      expect(exception.displayMessage, isNull);
      expect(exception.debugDetail, isNull);
      expect(exception.reservedUntil, isNull);
      expect(exception.expiredAt, isNull);
      expect(exception.limit, isNull);
      expect(exception.retryAfter, isNull);
      expect(exception.validationFields, isEmpty);
    });
  });

  group('OrderException.fromEnvelope — typed fields (ADR-0017 Amendment 2 '
      'A2-D2, ADR-0037 Amendment 2 A2-D2)', () {
    test('reservedUntil is a real DateTime parsed from the reserved_until '
        'row, not just non-null', () {
      final envelope = backendEnvelopeFixture(
        code: 'POSTER_NOT_AVAILABLE',
        message: 'มีคนจองใบนี้อยู่แล้ว',
        details: [
          {'field': 'reserved_until', 'message': '2026-09-16T15:30:00.000Z'},
        ],
      );

      final exception = OrderException.fromEnvelope(envelope);

      expect(
        exception.reservedUntil,
        DateTime.parse('2026-09-16T15:30:00.000Z'),
      );
    });

    test('expiredAt is a real DateTime parsed from the expired_at row', () {
      final envelope = backendEnvelopeFixture(
        code: 'RESERVATION_NOT_ACTIVE',
        message: 'การจองหมดอายุแล้ว',
        details: [
          {'field': 'expired_at', 'message': '2026-09-16T09:00:00.000Z'},
        ],
      );

      final exception = OrderException.fromEnvelope(envelope);

      expect(exception.expiredAt, DateTime.parse('2026-09-16T09:00:00.000Z'));
    });

    test('limit is a real int parsed from the limit row', () {
      final envelope = backendEnvelopeFixture(
        code: 'RESERVATION_LIMIT_EXCEEDED',
        message: 'จองครบจำนวนที่กำหนดแล้ว',
        details: [
          {'field': 'limit', 'message': '3'},
        ],
      );

      final exception = OrderException.fromEnvelope(envelope);

      expect(exception.limit, 3);
    });

    test('retryAfter comes from the Retry-After header, not from a details '
        'row (ADR-0037 Amendment 2 A2-D2 — a 429 sends details: null)', () {
      final envelope = backendEnvelopeFixture(
        code: 'RESERVE_RATE_LIMITED',
        message: 'รัวเกินไป',
        headers: {
          'Retry-After': ['42'],
        },
      );

      final exception = OrderException.fromEnvelope(envelope);

      expect(exception.retryAfter, const Duration(seconds: 42));
    });

    test('retryAfter is null when there is no Retry-After header', () {
      final envelope = backendEnvelopeFixture(
        code: 'POSTER_NOT_AVAILABLE',
        message: 'มีคนจองใบนี้อยู่แล้ว',
      );

      final exception = OrderException.fromEnvelope(envelope);

      expect(exception.retryAfter, isNull);
    });
  });

  group('OrderException.fromEnvelope — parse failures degrade to null, '
      'never throw (ADR-0017 Amendment 2 A2-D2)', () {
    // 🔴 Mutation-locking test — the exact case ADR-0017 Amendment 2 and
    // ADR-0037 Amendment 2 A2-D2 both call out by name: on every code
    // except VALIDATION_ERROR, `details[].message` is contractually a bare
    // machine value (backend-side test enforces it). If a row ever carries
    // Thai prose instead — the VALIDATION_ERROR shape leaking onto another
    // code, or the backend-side guarantee lapsing — this must degrade to
    // `null`, not silently mis-parse or throw. Flip this fixture's message
    // back to a real ISO string and this same test proves the happy path:
    // that is the sibling assertion above ("reservedUntil is a real
    // DateTime..."). Verified locally by mutating `_dateTimeField` to
    // `return null;` unconditionally — the sibling happy-path test above
    // goes red while this one stays green, confirming the two together
    // actually exercise both branches of `DateTime.tryParse`.
    test('reservedUntil is null (not a crash, not a mis-parsed value) when '
        'the reserved_until row carries Thai prose instead of ISO-8601', () {
      final envelope = backendEnvelopeFixture(
        code: 'POSTER_NOT_AVAILABLE',
        message: 'มีคนจองใบนี้อยู่แล้ว',
        details: [
          {'field': 'reserved_until', 'message': 'จองไว้ถึง 15:30 น.'},
        ],
      );

      final exception = OrderException.fromEnvelope(envelope);

      expect(exception.reservedUntil, isNull);
    });

    test('limit is null when the limit row is not a plain integer', () {
      final envelope = backendEnvelopeFixture(
        code: 'RESERVATION_LIMIT_EXCEEDED',
        message: 'จองครบจำนวนที่กำหนดแล้ว',
        details: [
          {'field': 'limit', 'message': 'สามใบ'},
        ],
      );

      final exception = OrderException.fromEnvelope(envelope);

      expect(exception.limit, isNull);
    });

    test('every typed field is null when details is absent entirely — no '
        'throw', () {
      final envelope = backendEnvelopeFixture(
        code: 'SERVER_ERROR',
        message: 'เกิดข้อผิดพลาด',
      );

      final exception = OrderException.fromEnvelope(envelope);

      expect(exception.reservedUntil, isNull);
      expect(exception.expiredAt, isNull);
      expect(exception.limit, isNull);
    });

    test('every typed field is null when details is present but is not a '
        'JSON array (malformed shape) — no throw', () {
      final envelope = backendEnvelopeFixture(
        code: 'POSTER_NOT_AVAILABLE',
        message: 'มีคนจองใบนี้อยู่แล้ว',
        details: 'not a list',
      );

      final exception = OrderException.fromEnvelope(envelope);

      expect(exception.reservedUntil, isNull);
      expect(exception.expiredAt, isNull);
      expect(exception.limit, isNull);
    });
  });

  group('OrderException.fromEnvelope — validationFields (ADR-0017 D3)', () {
    test('lists the field names from details[] when code is '
        'VALIDATION_ERROR', () {
      final envelope = backendEnvelopeFixture(
        code: 'VALIDATION_ERROR',
        message: 'ข้อมูลไม่ถูกต้อง',
        details: [
          {'field': 'shipping_address_line1', 'message': 'field required'},
          {'field': 'shipping_phone', 'message': 'field required'},
        ],
      );

      final exception = OrderException.fromEnvelope(envelope);

      expect(exception.validationFields, [
        'shipping_address_line1',
        'shipping_phone',
      ]);
    });

    test('F5 — strips a dotted prefix down to the last segment, so a nested '
        'field name matches CheckoutAddressForm\'s bare field-name checks '
        '(shipping_address.postal_code → postal_code), while a bare field '
        'name (reservation_id, no dot at all) is left unchanged. 🔴 '
        'mutation-locking: removing the strip in _stripFieldPrefix (returning '
        'row.field as-is) turns the first expectation below red while every '
        'other test in this group stays green.', () {
      final envelope = backendEnvelopeFixture(
        code: 'VALIDATION_ERROR',
        message: 'ข้อมูลไม่ถูกต้อง',
        details: [
          {
            'field': 'shipping_address.postal_code',
            'message': 'ensure this value has at most 10 characters',
          },
          {'field': 'reservation_id', 'message': 'field required'},
        ],
      );

      final exception = OrderException.fromEnvelope(envelope);

      expect(exception.validationFields, ['postal_code', 'reservation_id']);
    });

    test('is empty for a non-VALIDATION_ERROR code even when details[] has '
        'rows (ADR-0017 D3 — only VALIDATION_ERROR rows are field-name '
        'prose; other codes\' rows are the typed values above, not form '
        'field names)', () {
      final envelope = backendEnvelopeFixture(
        code: 'POSTER_NOT_AVAILABLE',
        message: 'มีคนจองใบนี้อยู่แล้ว',
        details: [
          {'field': 'reserved_until', 'message': '2026-09-16T15:30:00.000Z'},
        ],
      );

      final exception = OrderException.fromEnvelope(envelope);

      expect(exception.validationFields, isEmpty);
    });
  });

  group('OrderException.toString() (ADR-0017 D5)', () {
    test('never returns displayMessage or debugDetail — only the code', () {
      final envelope = backendEnvelopeFixture(
        code: 'POSTER_NOT_AVAILABLE',
        message: 'ข้อความลับที่ห้ามหลุดผ่าน toString()',
      );
      final exception = OrderException.fromEnvelope(
        envelope,
        debugDetail: 'raw SDK text that must never surface here',
      );

      final rendered = exception.toString();

      expect(rendered, 'OrderException(code: POSTER_NOT_AVAILABLE)');
      expect(rendered, isNot(contains('ข้อความลับ')));
      expect(rendered, isNot(contains('raw SDK text')));
    });
  });
}
