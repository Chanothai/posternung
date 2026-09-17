import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/features/checkout/domain/entities/reservation.dart';

void main() {
  // T is "server now". A reservation created 45 minutes ago with 15 minutes
  // left is what a 200 replay (ADR-0037 A5-D1) looks like; a 201 has
  // createdAt ≈ serverReceivedAt.
  final DateTime t = DateTime.utc(2026, 9, 16, 15, 45);

  group('Reservation.countdownSpan', () {
    test('uses expiresAt - serverReceivedAt when the server told us its '
        'now: a 45-minute-old reservation replayed as 200 has 15:00 left, '
        'not 60:00 (SCR-07 AC-8 · code-critic 2026-09-17 F-Med). 🔴 '
        'mutation-locking: anchoring on createdAt regardless turns this '
        'red', () {
      final reservation = Reservation(
        id: 'r1',
        posterId: 'p1',
        createdAt: t.subtract(const Duration(minutes: 45)),
        expiresAt: t.add(const Duration(minutes: 15)),
        serverReceivedAt: t,
      );

      expect(reservation.countdownSpan, const Duration(minutes: 15));
      expect(reservation.countdownSpan, isNot(const Duration(minutes: 60)));
    });

    test('falls back to expiresAt - createdAt when serverReceivedAt is null '
        '(no/unparseable Date header) — exact for a fresh 201 row', () {
      final reservation = Reservation(
        id: 'r1',
        posterId: 'p1',
        createdAt: t.subtract(const Duration(minutes: 45)),
        expiresAt: t.add(const Duration(minutes: 15)),
        serverReceivedAt: null,
      );

      expect(reservation.countdownSpan, const Duration(minutes: 60));
    });

    test('a server now already past expiresAt yields a negative span (the '
        'countdown clamps to zero, the entity does not lie about it)', () {
      final reservation = Reservation(
        id: 'r1',
        posterId: 'p1',
        createdAt: t.subtract(const Duration(minutes: 90)),
        expiresAt: t.subtract(const Duration(minutes: 30)),
        serverReceivedAt: t,
      );

      expect(reservation.countdownSpan, const Duration(minutes: -30));
    });
  });
}
