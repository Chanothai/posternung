import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/features/checkout/domain/entities/order.dart';
import 'package:posternung/features/checkout/domain/entities/order_status.dart';
import 'package:posternung/features/checkout/domain/entities/shipping_address.dart';
import 'package:posternung/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:posternung/features/checkout/domain/usecases/create_order.dart';

class MockCheckoutRepository extends Mock implements CheckoutRepository {}

void main() {
  test('CreateOrder.call() delegates to CheckoutRepository.createOrder with '
      'the exact reservationId and address it was given', () async {
    final repository = MockCheckoutRepository();
    const address = ShippingAddress(
      recipientName: 'สมชาย ใจดี',
      recipientPhone: '0812345678',
      addressLine: '123 ถนนสุขุมวิท',
      province: 'กรุงเทพมหานคร',
      postalCode: '10110',
    );
    final order = Order(
      id: 'o1',
      orderNo: 'PN-260916-0001',
      posterId: 'p1',
      status: OrderStatus.awaitingPayment,
      itemPrice: '450.00',
      shippingFee: '0.00',
      totalAmount: '450.00',
      itemTitle: 'Blade Runner',
      createdAt: DateTime.utc(2026, 9, 16, 15, 31),
    );
    when(
      () =>
          repository.createOrder(reservationId: 'r1', shippingAddress: address),
    ).thenAnswer((_) async => order);

    final result = await CreateOrder(
      repository,
    ).call(reservationId: 'r1', shippingAddress: address);

    expect(result, same(order));
    verify(
      () =>
          repository.createOrder(reservationId: 'r1', shippingAddress: address),
    ).called(1);
  });
}
