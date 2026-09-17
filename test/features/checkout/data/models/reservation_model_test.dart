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
    // Not on the wire — only the data source can set it (from the `Date`
    // header), so a bare `fromJson` leaves it null.
    expect(entity.serverReceivedAt, isNull);
  });

  test('serverReceivedAt is ignored by fromJson even if a body carries a '
      'field of that name (it comes from the header, never the body), and '
      'copyWith carries it through to the entity', () {
    final model = ReservationModel.fromJson({
      'id': 'r1',
      'poster_id': 'p1',
      'user_id': 'u1',
      'status': 'active',
      'expires_at': '2026-09-16T16:30:00Z',
      'created_at': '2026-09-16T15:30:00Z',
      'server_received_at': '2026-09-16T16:00:00Z',
      'serverReceivedAt': '2026-09-16T16:00:00Z',
    });
    expect(model.serverReceivedAt, isNull);

    final received = DateTime.utc(2026, 9, 16, 16, 15);
    final entity = model.copyWith(serverReceivedAt: received).toEntity();
    expect(entity.serverReceivedAt, received);
    // toJson never emits it either — nothing here goes back to the server,
    // but the DTO must not invent a wire field.
    expect(
      model.copyWith(serverReceivedAt: received).toJson().keys,
      isNot(contains('serverReceivedAt')),
    );
  });
}
