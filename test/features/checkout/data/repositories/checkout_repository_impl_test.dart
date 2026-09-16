import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/order_exception.dart';
import 'package:posternung/features/checkout/data/datasources/checkout_remote_data_source.dart';
import 'package:posternung/features/checkout/data/models/order_model.dart';
import 'package:posternung/features/checkout/data/models/reservation_model.dart';
import 'package:posternung/features/checkout/data/models/shipping_address_model.dart';
import 'package:posternung/features/checkout/data/repositories/checkout_repository_impl.dart';
import 'package:posternung/features/checkout/domain/entities/shipping_address.dart';

class MockCheckoutRemoteDataSource extends Mock
    implements CheckoutRemoteDataSource {}

void main() {
  late MockCheckoutRemoteDataSource dataSource;
  late CheckoutRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(
      const ShippingAddressModel(
        recipientName: 'x',
        recipientPhone: 'x',
        addressLine: 'x',
        province: 'x',
        postalCode: 'x',
      ),
    );
  });

  setUp(() {
    dataSource = MockCheckoutRemoteDataSource();
    repository = CheckoutRepositoryImpl(dataSource);
  });

  group('reserveListing', () {
    test('converts the datasource model to an entity', () async {
      when(() => dataSource.reserveListing('p1')).thenAnswer(
        (_) async => ReservationModel.fromJson({
          'id': 'r1',
          'poster_id': 'p1',
          'user_id': 'u1',
          'status': 'active',
          'expires_at': '2026-09-16T16:30:00Z',
          'created_at': '2026-09-16T15:30:00Z',
        }),
      );

      final result = await repository.reserveListing('p1');

      expect(result.id, 'r1');
    });

    test('rethrows an OrderException from the datasource unchanged', () async {
      when(
        () => dataSource.reserveListing('p1'),
      ).thenThrow(const OrderException(code: 'POSTER_NOT_AVAILABLE'));

      await expectLater(
        () => repository.reserveListing('p1'),
        throwsA(
          isA<OrderException>().having(
            (e) => e.code,
            'code',
            'POSTER_NOT_AVAILABLE',
          ),
        ),
      );
    });

    test('wraps a non-OrderException failure with a fixed code, never '
        'composed from runtimeType (ADR-0017 D6)', () async {
      when(() => dataSource.reserveListing('p1')).thenThrow(StateError('boom'));

      await expectLater(
        () => repository.reserveListing('p1'),
        throwsA(
          isA<OrderException>().having(
            (e) => e.code,
            'code',
            'checkout_repo_reserve_unexpected',
          ),
        ),
      );
    });
  });

  group('createOrder', () {
    const address = ShippingAddress(
      recipientName: 'สมชาย ใจดี',
      recipientPhone: '0812345678',
      addressLine: '123 ถนนสุขุมวิท',
      province: 'กรุงเทพมหานคร',
      postalCode: '10110',
    );

    test('converts the ShippingAddress entity to a model before calling the '
        'datasource, and converts the response back to an entity', () async {
      when(
        () => dataSource.createOrder(
          reservationId: any(named: 'reservationId'),
          shippingAddress: any(named: 'shippingAddress'),
        ),
      ).thenAnswer(
        (_) async => OrderModel.fromJson({
          'id': 'o1',
          'order_no': 'PN-260916-0001',
          'poster_id': 'p1',
          'status': 'AWAITING_PAYMENT',
          'item_price': '450.00',
          'shipping_fee': '0.00',
          'total_amount': '450.00',
          'item_title': 'Blade Runner',
          'created_at': '2026-09-16T15:31:00Z',
        }),
      );

      final result = await repository.createOrder(
        reservationId: 'r1',
        shippingAddress: address,
      );

      expect(result.id, 'o1');
      final captured = verify(
        () => dataSource.createOrder(
          reservationId: captureAny(named: 'reservationId'),
          shippingAddress: captureAny(named: 'shippingAddress'),
        ),
      ).captured;
      expect(captured[0], 'r1');
      final sentModel = captured[1] as ShippingAddressModel;
      expect(sentModel.recipientName, 'สมชาย ใจดี');
      expect(sentModel.province, 'กรุงเทพมหานคร');
    });

    test('rethrows an OrderException from the datasource unchanged', () async {
      when(
        () => dataSource.createOrder(
          reservationId: any(named: 'reservationId'),
          shippingAddress: any(named: 'shippingAddress'),
        ),
      ).thenThrow(const OrderException(code: 'RESERVATION_NOT_ACTIVE'));

      await expectLater(
        () => repository.createOrder(
          reservationId: 'r1',
          shippingAddress: address,
        ),
        throwsA(
          isA<OrderException>().having(
            (e) => e.code,
            'code',
            'RESERVATION_NOT_ACTIVE',
          ),
        ),
      );
    });
  });
}
