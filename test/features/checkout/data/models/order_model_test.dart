import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/features/checkout/data/models/order_model.dart';
import 'package:posternung/features/checkout/domain/entities/order_status.dart';

Map<String, dynamic> _json({required String status}) => {
  'id': 'o1',
  'order_no': 'PN-260916-0001',
  'poster_id': 'p1',
  'status': status,
  'item_price': '450.00',
  'shipping_fee': '0.00',
  'total_amount': '450.00',
  'item_title': 'Blade Runner',
  'created_at': '2026-09-16T15:31:00Z',
};

void main() {
  group('OrderModel.fromJson — status (`OrderStatus`, 8 values)', () {
    const cases = <String, OrderStatus>{
      'AWAITING_PAYMENT': OrderStatus.awaitingPayment,
      'PAYMENT_REVIEW': OrderStatus.paymentReview,
      'AWAITING_SHIPMENT': OrderStatus.awaitingShipment,
      'SHIPPED': OrderStatus.shipped,
      'COMPLETED': OrderStatus.completed,
      'CANCELLED': OrderStatus.cancelled,
      'DISPUTED': OrderStatus.disputed,
      'REFUNDED': OrderStatus.refunded,
    };

    for (final entry in cases.entries) {
      test(
        '"${entry.key}" deserializes to OrderStatus.${entry.value.name}',
        () {
          final model = OrderModel.fromJson(_json(status: entry.key));
          expect(model.toEntity().status, entry.value);
        },
      );
    }

    // Closed-world over the enum itself — if a status is ever added to
    // `OrderStatus` without a row above, this fails rather than the gap
    // going unnoticed.
    test('every OrderStatus value has exactly one covering case above', () {
      expect(cases.values.toSet(), OrderStatus.values.toSet());
      expect(cases, hasLength(OrderStatus.values.length));
    });

    test('an unrecognized status string degrades to null, not a throw '
        '(distinct from PosterDetailModel, which throws)', () {
      final model = OrderModel.fromJson(_json(status: 'SOME_FUTURE_STATUS'));
      expect(() => model.toEntity(), returnsNormally);
      expect(model.toEntity().status, isNull);
    });

    test('money fields stay String end-to-end, never parsed to num', () {
      final model = OrderModel.fromJson(_json(status: 'AWAITING_PAYMENT'));
      expect(model.itemPrice, isA<String>());
      expect(model.itemPrice, '450.00');
      expect(model.shippingFee, '0.00');
      expect(model.totalAmount, '450.00');
    });
  });
}
