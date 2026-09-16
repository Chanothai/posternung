import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/features/checkout/data/models/reservation_model.dart';

void main() {
  test('ReservationModel.fromJson parses ReservationResponse and toEntity() '
      'narrows to id/posterId/expiresAt/createdAt', () {
    final model = ReservationModel.fromJson({
      'id': 'r1',
      'poster_id': 'p1',
      'user_id': 'u1',
      'status': 'active',
      'expires_at': '2026-09-16T16:30:00Z',
      'created_at': '2026-09-16T15:30:00Z',
    });

    final entity = model.toEntity();
    expect(entity.id, 'r1');
    expect(entity.posterId, 'p1');
    expect(entity.expiresAt, DateTime.parse('2026-09-16T16:30:00Z'));
    expect(entity.createdAt, DateTime.parse('2026-09-16T15:30:00Z'));
  });
}
