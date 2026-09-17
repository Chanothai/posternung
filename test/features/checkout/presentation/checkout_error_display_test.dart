import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/error/order_exception.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/checkout/presentation/checkout_error_display.dart';

import '../../../support/backend_envelope_fixture.dart';

OrderException _fromEnvelope({
  required String code,
  String? message,
  Object? details,
  Map<String, List<String>>? headers,
}) => OrderException.fromEnvelope(
  backendEnvelopeFixture(
    code: code,
    message: message,
    details: details,
    headers: headers,
  ),
);

void main() {
  group('checkoutOrderErrorDisplayMessage — orders table (POST /orders)', () {
    test('RESERVATION_NOT_FOUND', () {
      final e = _fromEnvelope(code: 'RESERVATION_NOT_FOUND');
      expect(
        checkoutOrderErrorDisplayMessage(e, fallback: 'fallback'),
        AppStrings.checkoutErrorReservationNotFound,
      );
    });

    test('RESERVATION_NOT_ACTIVE with expired_at → "หมดเวลาแล้ว" wording', () {
      final e = _fromEnvelope(
        code: 'RESERVATION_NOT_ACTIVE',
        details: [
          {'field': 'expired_at', 'message': '2026-09-16T15:30:00Z'},
        ],
      );
      expect(
        checkoutOrderErrorDisplayMessage(e, fallback: 'fallback'),
        AppStrings.checkoutErrorReservationExpired,
      );
    });

    test('RESERVATION_NOT_ACTIVE with NO expired_at → "ถูกใช้ไปแล้ว" wording '
        '— same error_code, different message, chosen by the parsed field '
        'not a second code', () {
      final e = _fromEnvelope(code: 'RESERVATION_NOT_ACTIVE');
      expect(
        checkoutOrderErrorDisplayMessage(e, fallback: 'fallback'),
        AppStrings.checkoutErrorReservationUsed,
      );
    });

    test('POSTER_NOT_AVAILABLE (order path — no reserved_until here)', () {
      final e = _fromEnvelope(code: 'POSTER_NOT_AVAILABLE');
      expect(
        checkoutOrderErrorDisplayMessage(e, fallback: 'fallback'),
        AppStrings.checkoutErrorPosterGoneAtOrder,
      );
    });

    test('VALIDATION_ERROR renders the fixed Thai copy, never the English '
        'validator prose from details[].message', () {
      final e = _fromEnvelope(
        code: 'VALIDATION_ERROR',
        message: 'ข้อมูลที่ส่งมาไม่ถูกต้อง',
        details: [
          {
            'field': 'shipping_address.postal_code',
            'message': 'ensure this value has at most 10 characters',
          },
        ],
      );
      final message = checkoutOrderErrorDisplayMessage(e, fallback: 'fallback');
      expect(message, AppStrings.checkoutErrorValidation);
      expect(message, isNot(contains('ensure this value')));
    });

    test('checkout_countdown_expired (client-driven AC-11 timeout) renders '
        'the same wording as a backend-confirmed expiry', () {
      const e = OrderException(code: kCheckoutCountdownExpiredCode);
      expect(
        checkoutOrderErrorDisplayMessage(e, fallback: 'fallback'),
        AppStrings.checkoutErrorReservationExpired,
      );
    });

    test('transport codes reuse the shared network/server Thai copy', () {
      expect(
        checkoutOrderErrorDisplayMessage(
          const OrderException(code: 'network_error'),
          fallback: 'fallback',
        ),
        AppStrings.authErrorNetwork,
      );
      expect(
        checkoutOrderErrorDisplayMessage(
          const OrderException(code: 'server_error'),
          fallback: 'fallback',
        ),
        AppStrings.authErrorServer,
      );
    });

    test('an unrecognized code with a backend displayMessage uses it (D4 '
        'step 2)', () {
      final e = _fromEnvelope(
        code: 'SOME_FUTURE_CODE',
        message: 'ข้อความจากแบ็กเอนด์',
      );
      expect(
        checkoutOrderErrorDisplayMessage(e, fallback: 'fallback'),
        'ข้อความจากแบ็กเอนด์',
      );
    });

    test('an unrecognized code with no displayMessage falls back (D4 step '
        '3)', () {
      const e = OrderException(code: 'totally_unknown');
      expect(
        checkoutOrderErrorDisplayMessage(e, fallback: 'fallback text'),
        'fallback text',
      );
    });
  });

  group('reserveErrorDisplayMessage — reserve table (SCR-07 B3 — called from '
      "poster/'s PosterBuyNowButton)", () {
    test('BUYER_IS_SELLER', () {
      final e = _fromEnvelope(code: 'BUYER_IS_SELLER');
      expect(
        reserveErrorDisplayMessage(e, fallback: 'fallback'),
        AppStrings.checkoutErrorBuyerIsSeller,
      );
    });

    test('POSTER_ALREADY_RESERVED', () {
      final e = _fromEnvelope(code: 'POSTER_ALREADY_RESERVED');
      expect(
        reserveErrorDisplayMessage(e, fallback: 'fallback'),
        AppStrings.checkoutErrorAlreadyReserved,
      );
    });

    test('BUYER_HAS_LIVE_ORDER with a parsed order_no composes the sentence '
        'around the number (ADR-0037 Amendment 5 A5-D4) — the backend\'s '
        'own `message` is never what is shown', () {
      final e = _fromEnvelope(
        code: 'BUYER_HAS_LIVE_ORDER',
        message: 'คุณสั่งซื้อโปสเตอร์ใบนี้แล้ว',
        details: [
          {'field': 'order_no', 'message': 'PN-260916-0001'},
        ],
      );
      final shown = reserveErrorDisplayMessage(e, fallback: 'fallback');
      expect(
        shown,
        '${AppStrings.checkoutErrorBuyerHasLiveOrderPrefix}'
        'PN-260916-0001'
        '${AppStrings.checkoutErrorBuyerHasLiveOrderSuffix}',
      );
      expect(shown, isNot('คุณสั่งซื้อโปสเตอร์ใบนี้แล้ว'));
      expect(shown, isNot('fallback'));
    });

    test('BUYER_HAS_LIVE_ORDER with NO usable order_no uses the bracket-free '
        'sentence — never "()" and never the backend prose', () {
      final e = _fromEnvelope(
        code: 'BUYER_HAS_LIVE_ORDER',
        message: 'คุณสั่งซื้อโปสเตอร์ใบนี้แล้ว',
        details: [
          {'field': 'order_no', 'message': 'เลขที่ PN-260916-0001 รอชำระเงิน'},
        ],
      );
      final shown = reserveErrorDisplayMessage(e, fallback: 'fallback');
      expect(shown, AppStrings.checkoutErrorBuyerHasLiveOrderNoNumber);
      expect(shown, isNot(contains('(')));
      expect(shown, isNot(contains('PN-')));
    });

    test('POSTER_NOT_AVAILABLE with reserved_until composes the absolute '
        'HH:mm local time into the message', () {
      final e = _fromEnvelope(
        code: 'POSTER_NOT_AVAILABLE',
        details: [
          // A fixed UTC instant so the expected local rendering is
          // deterministic regardless of the machine's own timezone: format
          // the same instant the same way the mapper does, rather than
          // hardcoding a clock-dependent string.
          {'field': 'reserved_until', 'message': '2026-09-16T08:30:00Z'},
        ],
      );
      final expectedLocal = DateTime.parse('2026-09-16T08:30:00Z').toLocal();
      final hh = expectedLocal.hour.toString().padLeft(2, '0');
      final mm = expectedLocal.minute.toString().padLeft(2, '0');

      final message = reserveErrorDisplayMessage(e, fallback: 'fallback');

      expect(message, contains('$hh:$mm'));
      expect(
        message,
        '${AppStrings.checkoutErrorPosterReservedUntilPrefix}'
        '$hh:$mm'
        '${AppStrings.checkoutErrorPosterReservedUntilSuffix}',
      );
    });

    test('POSTER_NOT_AVAILABLE with NO reserved_until (sold out) never says '
        '"ถึง null น."', () {
      final e = _fromEnvelope(code: 'POSTER_NOT_AVAILABLE');
      final message = reserveErrorDisplayMessage(e, fallback: 'fallback');
      expect(message, AppStrings.checkoutErrorPosterSoldOut);
      expect(message, isNot(contains('null')));
    });

    test('RESERVATION_LIMIT_EXCEEDED with a parsed limit composes the '
        'number into the message', () {
      final e = _fromEnvelope(
        code: 'RESERVATION_LIMIT_EXCEEDED',
        details: [
          {'field': 'limit', 'message': '3'},
        ],
      );
      expect(
        reserveErrorDisplayMessage(e, fallback: 'fallback'),
        '${AppStrings.checkoutErrorReservationLimitExceededPrefix}'
        '3'
        '${AppStrings.checkoutErrorReservationLimitExceededSuffix}',
      );
    });

    test('RESERVATION_LIMIT_EXCEEDED with an unparseable limit falls back '
        'to displayMessage rather than rendering a null-ish sentence', () {
      final e = _fromEnvelope(
        code: 'RESERVATION_LIMIT_EXCEEDED',
        message: 'ข้อความจากแบ็กเอนด์',
        details: [
          {'field': 'limit', 'message': 'not-a-number'},
        ],
      );
      expect(
        reserveErrorDisplayMessage(e, fallback: 'fallback'),
        'ข้อความจากแบ็กเอนด์',
      );
    });

    test('RESERVE_RATE_LIMITED with a parsed Retry-After composes the '
        'seconds into the message', () {
      final e = _fromEnvelope(
        code: 'RESERVE_RATE_LIMITED',
        headers: {
          'Retry-After': ['30'],
        },
      );
      expect(
        reserveErrorDisplayMessage(e, fallback: 'fallback'),
        '${AppStrings.checkoutErrorRateLimitedPrefix}'
        '30'
        '${AppStrings.checkoutErrorRateLimitedSuffix}',
      );
    });

    test('transport codes reuse the shared network/server Thai copy', () {
      expect(
        reserveErrorDisplayMessage(
          const OrderException(code: 'network_error'),
          fallback: 'fallback',
        ),
        AppStrings.authErrorNetwork,
      );
    });
  });
}
