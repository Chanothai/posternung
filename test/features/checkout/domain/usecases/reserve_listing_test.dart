import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/features/checkout/domain/entities/reservation.dart';
import 'package:posternung/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:posternung/features/checkout/domain/usecases/reserve_listing.dart';

class MockCheckoutRepository extends Mock implements CheckoutRepository {}

void main() {
  test('ReserveListing.call() delegates to CheckoutRepository.reserveListing '
      'with the exact posterId it was given', () async {
    final repository = MockCheckoutRepository();
    final reservation = Reservation(
      id: 'r1',
      posterId: 'p1',
      expiresAt: DateTime.utc(2026, 9, 16, 16, 30),
      createdAt: DateTime.utc(2026, 9, 16, 15, 30),
    );
    when(
      () => repository.reserveListing('p1'),
    ).thenAnswer((_) async => reservation);

    final result = await ReserveListing(repository).call('p1');

    expect(result, same(reservation));
    verify(() => repository.reserveListing('p1')).called(1);
  });
}
