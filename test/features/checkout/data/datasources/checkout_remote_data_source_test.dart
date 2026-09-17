import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/order_exception.dart';
import 'package:posternung/features/checkout/data/datasources/checkout_remote_data_source.dart';
import 'package:posternung/features/checkout/data/models/shipping_address_model.dart';

class MockDio extends Mock implements Dio {}

class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

/// A wire-level response for the real-`Dio` tests below — the mocked-`Dio`
/// tests never run Dio's own `validateStatus`, so they cannot say anything
/// about which HTTP status codes count as success (same shape as
/// `test/core/network/auth_interceptor_test.dart`).
ResponseBody _wire(
  Map<String, dynamic> data,
  int statusCode, {
  Map<String, List<String>> extraHeaders = const {},
}) => ResponseBody.fromString(
  jsonEncode(data),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...extraHeaders,
  },
);

Response<Map<String, dynamic>> _resp(Map<String, dynamic> data) => Response(
  data: data,
  requestOptions: RequestOptions(path: '/'),
);

// Same reasoning as `poster_remote_data_source_test.dart`'s `_dioError`:
// going through Dio's own `.badResponse`/`.connectionError` factories is
// what makes every `displayMessage == null` negative assertion below
// non-vacuous (a bare `DioException(...)` leaves `.message` at `null`,
// which a mutant leaking `e.message` into `displayMessage` couldn't be
// caught by).
DioException _dioError(int status, {Object? data}) {
  final requestOptions = RequestOptions(path: '/');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: requestOptions,
    response: Response(
      statusCode: status,
      data: data,
      requestOptions: requestOptions,
    ),
  );
}

DioException _dioNoResponse() => DioException.connectionError(
  requestOptions: RequestOptions(path: '/'),
  reason: 'Connection refused',
);

Map<String, dynamic> _reservationJson() => {
  'id': 'r1',
  'poster_id': 'p1',
  'user_id': 'u1',
  'status': 'active',
  'expires_at': '2026-09-16T16:30:00Z',
  'created_at': '2026-09-16T15:30:00Z',
};

Map<String, dynamic> _orderJson() => {
  'id': 'o1',
  'order_no': 'PN-260916-0001',
  'poster_id': 'p1',
  'status': 'AWAITING_PAYMENT',
  'item_price': '450.00',
  'shipping_fee': '0.00',
  'total_amount': '450.00',
  'item_title': 'Blade Runner',
  'created_at': '2026-09-16T15:31:00Z',
};

ShippingAddressModel _addressModel() => const ShippingAddressModel(
  recipientName: 'สมชาย ใจดี',
  recipientPhone: '0812345678',
  addressLine: '123 ถนนสุขุมวิท',
  subDistrict: null,
  district: null,
  province: 'กรุงเทพมหานคร',
  postalCode: '10110',
);

void main() {
  late MockDio dio;
  late CheckoutRemoteDataSourceImpl dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = CheckoutRemoteDataSourceImpl(dio);
  });

  group('reserveListing', () {
    test('POSTs /api/v1/listings/{poster_id}/reserve with NO body', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _resp(_reservationJson()));

      final result = await dataSource.reserveListing('p1');

      expect(result.id, 'r1');
      final captured = verify(
        () => dio.post<Map<String, dynamic>>(captureAny()),
      ).captured;
      expect(captured.single, '/api/v1/listings/p1/reserve');
      // No overload of `post` taking `data:`/`options:` was ever called —
      // this is what proves the request genuinely carries no body, not
      // merely that the happy path parses.
      verifyNever(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      );
    });

    test('surfaces a 409 POSTER_NOT_AVAILABLE envelope with the typed '
        'reserved_until field', () async {
      when(() => dio.post<Map<String, dynamic>>(any())).thenThrow(
        _dioError(
          409,
          data: {
            'error_code': 'POSTER_NOT_AVAILABLE',
            'message': 'โปสเตอร์นี้ถูกจองแล้ว',
            'details': [
              {
                'field': 'reserved_until',
                'message': '2026-09-16T15:30:00+07:00',
              },
            ],
          },
        ),
      );

      await expectLater(
        () => dataSource.reserveListing('p1'),
        throwsA(
          isA<OrderException>()
              .having((e) => e.code, 'code', 'POSTER_NOT_AVAILABLE')
              .having(
                (e) => e.reservedUntil,
                'reservedUntil',
                DateTime.parse('2026-09-16T15:30:00+07:00'),
              ),
        ),
      );
    });

    test('maps a no-response failure to code network_error', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any()),
      ).thenThrow(_dioNoResponse());

      await expectLater(
        () => dataSource.reserveListing('p1'),
        throwsA(
          isA<OrderException>()
              .having((e) => e.code, 'code', 'network_error')
              .having((e) => e.displayMessage, 'displayMessage', isNull),
        ),
      );
    });

    test('maps a 5xx without an envelope to code server_error', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any()),
      ).thenThrow(_dioError(502));

      await expectLater(
        () => dataSource.reserveListing('p1'),
        throwsA(
          isA<OrderException>().having((e) => e.code, 'code', 'server_error'),
        ),
      );
    });
  });

  // ADR-0037 Amendment 5 A5-D1 — `POST /listings/{poster_id}/reserve` now
  // answers **200** (the buyer's own still-active reservation, unchanged)
  // as well as **201** (a new row). These run through a real `Dio` with a
  // mocked transport, because the status-code judgement lives in Dio's
  // `validateStatus` — a `MockDio` that returns a `Response` can neither
  // prove 200 is accepted nor that 409 is still rejected.
  group('reserveListing — HTTP status through a real Dio (A5-D1)', () {
    late MockHttpClientAdapter adapter;
    late CheckoutRemoteDataSourceImpl realDataSource;

    setUpAll(() {
      registerFallbackValue(RequestOptions(path: '/'));
    });

    setUp(() {
      adapter = MockHttpClientAdapter();
      realDataSource = CheckoutRemoteDataSourceImpl(
        Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = adapter,
      );
    });

    for (final status in const [200, 201]) {
      test('a $status body parses into the reservation — 200 (own existing '
          'reservation) and 201 (new) are both success', () async {
        when(
          () => adapter.fetch(any(), any(), any()),
        ).thenAnswer((_) async => _wire(_reservationJson(), status));

        final result = await realDataSource.reserveListing('p1');

        expect(result.id, 'r1');
        expect(result.expiresAt, DateTime.parse('2026-09-16T16:30:00Z'));
      });
    }

    // code-critic 2026-09-17 F-Med — the `Date` header is the server's own
    // clock at the instant it answered; it is what lets a 200 replay count
    // down from what is actually left. Only a real Dio carries response
    // headers from the adapter to `response.headers`, so these cannot be
    // written against `MockDio`.
    group('Date header → serverReceivedAt', () {
      test('a well-formed Date header lands on the model as a UTC instant, '
          'for both 200 (replay) and 201 (new row). 🔴 mutation-locking: '
          'dropping the `copyWith(serverReceivedAt:)` in the data source '
          'turns this red', () async {
        for (final status in const [200, 201]) {
          when(() => adapter.fetch(any(), any(), any())).thenAnswer(
            (_) async => _wire(
              _reservationJson(),
              status,
              extraHeaders: const {
                'date': ['Wed, 16 Sep 2026 16:15:00 GMT'],
              },
            ),
          );

          final result = await realDataSource.reserveListing('p1');

          expect(
            result.serverReceivedAt,
            DateTime.utc(2026, 9, 16, 16, 15),
            reason: 'status $status',
          );
          expect(
            result.toEntity().serverReceivedAt,
            DateTime.utc(2026, 9, 16, 16, 15),
          );
        }
      });

      test('no Date header → serverReceivedAt is null and the reserve still '
          'succeeds (fallback to createdAt happens in the entity, not '
          'here)', () async {
        when(
          () => adapter.fetch(any(), any(), any()),
        ).thenAnswer((_) async => _wire(_reservationJson(), 201));

        final result = await realDataSource.reserveListing('p1');

        expect(result.id, 'r1');
        expect(result.serverReceivedAt, isNull);
      });

      test('an unparseable Date header → null, no throw, reserve still '
          'succeeds (a bad header must never fail the reservation)', () async {
        when(() => adapter.fetch(any(), any(), any())).thenAnswer(
          (_) async => _wire(
            _reservationJson(),
            201,
            extraHeaders: const {
              'date': ['yesterday-ish'],
            },
          ),
        );

        final result = await realDataSource.reserveListing('p1');

        expect(result.id, 'r1');
        expect(result.serverReceivedAt, isNull);
      });

      test('a duplicated Date header → first value, no throw (Dio\'s '
          '`headers.value()` would throw on this; the data source must '
          'not use it)', () async {
        when(() => adapter.fetch(any(), any(), any())).thenAnswer(
          (_) async => _wire(
            _reservationJson(),
            201,
            extraHeaders: const {
              'date': [
                'Wed, 16 Sep 2026 16:15:00 GMT',
                'Wed, 16 Sep 2026 16:16:00 GMT',
              ],
            },
          ),
        );

        final result = await realDataSource.reserveListing('p1');

        expect(result.serverReceivedAt, DateTime.utc(2026, 9, 16, 16, 15));
      });
    });

    test('a 409 through the same real Dio still throws OrderException with '
        'the envelope code (negative: "2xx is success" is not "anything is '
        'success")', () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer(
        (_) async => _wire({
          'error_code': 'BUYER_HAS_LIVE_ORDER',
          'message': 'คุณสั่งซื้อโปสเตอร์ใบนี้แล้ว',
          'details': [
            {'field': 'order_no', 'message': 'PN-260916-0001'},
          ],
        }, 409),
      );

      await expectLater(
        () => realDataSource.reserveListing('p1'),
        throwsA(
          isA<OrderException>()
              .having((e) => e.code, 'code', 'BUYER_HAS_LIVE_ORDER')
              .having((e) => e.orderNo, 'orderNo', 'PN-260916-0001'),
        ),
      );
    });
  });

  group('createOrder', () {
    test('POSTs /api/v1/orders with the full snake_case body and parses '
        'the 201 response into an entity', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => _resp(_orderJson()));

      final result = await dataSource.createOrder(
        reservationId: 'r1',
        shippingAddress: _addressModel(),
      );

      expect(result.id, 'o1');
      expect(result.orderNo, 'PN-260916-0001');

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/api/v1/orders');
      final body = captured[1] as Map<String, dynamic>;
      expect(body['reservation_id'], 'r1');
      final address = body['shipping_address'] as Map<String, dynamic>;
      expect(address, {
        'recipient_name': 'สมชาย ใจดี',
        'recipient_phone': '0812345678',
        'address_line': '123 ถนนสุขุมวิท',
        'sub_district': null,
        'district': null,
        'province': 'กรุงเทพมหานคร',
        'postal_code': '10110',
      });
    });

    test('surfaces a 409 RESERVATION_NOT_ACTIVE envelope with the typed '
        'expired_at field', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(
        _dioError(
          409,
          data: {
            'error_code': 'RESERVATION_NOT_ACTIVE',
            'message': 'การจองหมดอายุแล้ว',
            'details': [
              {'field': 'expired_at', 'message': '2026-09-16T15:30:00Z'},
            ],
          },
        ),
      );

      await expectLater(
        () => dataSource.createOrder(
          reservationId: 'r1',
          shippingAddress: _addressModel(),
        ),
        throwsA(
          isA<OrderException>()
              .having((e) => e.code, 'code', 'RESERVATION_NOT_ACTIVE')
              .having(
                (e) => e.expiredAt,
                'expiredAt',
                DateTime.parse('2026-09-16T15:30:00Z'),
              ),
        ),
      );
    });

    test('surfaces a 422 VALIDATION_ERROR envelope with validationFields '
        'populated, stripped down to the bare field name (F5 — '
        '`OrderException.fromEnvelope` strips the `shipping_address.` '
        'prefix so `CheckoutAddressForm`\'s bare-name highlight check can '
        'match it)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(
        _dioError(
          422,
          data: {
            'error_code': 'VALIDATION_ERROR',
            'message': 'ข้อมูลที่ส่งมาไม่ถูกต้อง',
            'details': [
              {
                'field': 'shipping_address.postal_code',
                'message': 'ensure this value has at most 10 characters',
              },
            ],
          },
        ),
      );

      await expectLater(
        () => dataSource.createOrder(
          reservationId: 'r1',
          shippingAddress: _addressModel(),
        ),
        throwsA(
          isA<OrderException>()
              .having((e) => e.code, 'code', 'VALIDATION_ERROR')
              .having((e) => e.validationFields, 'validationFields', [
                'postal_code',
              ]),
        ),
      );
    });

    test('maps a no-response failure to code network_error', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(_dioNoResponse());

      await expectLater(
        () => dataSource.createOrder(
          reservationId: 'r1',
          shippingAddress: _addressModel(),
        ),
        throwsA(
          isA<OrderException>().having((e) => e.code, 'code', 'network_error'),
        ),
      );
    });
  });
}
