import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/restoration_status.dart';
import 'package:posternung/features/poster/presentation/widgets/poster_restoration_badge.dart';

void main() {
  Widget wrap(RestorationStatus? status) =>
      MaterialApp(home: PosterRestorationBadge(status: status));

  testWidgets('RESTORED renders a fact-only label', (tester) async {
    await tester.pumpWidget(wrap(RestorationStatus.restored));

    expect(find.text('ผ่านการบูรณะ'), findsOneWidget);
  });

  testWidgets('LINEN_BACKED renders its own fact-only label', (tester) async {
    await tester.pumpWidget(wrap(RestorationStatus.linenBacked));

    expect(find.text('ติดผ้าใบ (linen-backed)'), findsOneWidget);
  });

  // ADR-0011 §Amendment (2) / D2′, decided at GATE 3 — NONE, UNKNOWN, and
  // null must **all three** stay silent here. This is a **negative**
  // assertion left in place on purpose (not a deleted test): round 1 of
  // this feature had UNKNOWN render like RESTORED/LINEN_BACKED (on the
  // theory that ADR-0011 §D7's `NULL`≠`UNKNOWN` rule applied to this badge
  // too); GATE 3 overturned that and made `restoration_status` an explicit,
  // narrow exception to §D7. Keeping the assertion inverted — rather than
  // just removing the old "UNKNOWN renders" test — is what would catch
  // anyone re-adding `unknown` to `showsFor` later.
  for (final silent in [
    RestorationStatus.none,
    RestorationStatus.unknown,
    null,
  ]) {
    testWidgets('$silent renders nothing', (tester) async {
      await tester.pumpWidget(wrap(silent));

      expect(find.byType(Row), findsNothing);
      expect(find.byType(Icon), findsNothing);
      expect(find.text('ผ่านการบูรณะ'), findsNothing);
      expect(find.text('ติดผ้าใบ (linen-backed)'), findsNothing);
      expect(find.text('ตรวจแล้วระบุไม่ได้'), findsNothing);
    });
  }

  group('PosterRestorationBadge.showsFor — the single source of truth '
      'PosterDetailScreen also reads', () {
    test('true only for RESTORED and LINEN_BACKED', () {
      expect(
        PosterRestorationBadge.showsFor(RestorationStatus.restored),
        isTrue,
      );
      expect(
        PosterRestorationBadge.showsFor(RestorationStatus.linenBacked),
        isTrue,
      );
    });

    // Negative assertion, not a deletion — see the group comment above the
    // silent-value loop for why UNKNOWN belongs here now.
    test('false for NONE, UNKNOWN, and null', () {
      expect(PosterRestorationBadge.showsFor(RestorationStatus.none), isFalse);
      expect(
        PosterRestorationBadge.showsFor(RestorationStatus.unknown),
        isFalse,
      );
      expect(PosterRestorationBadge.showsFor(null), isFalse);
    });
  });

  testWidgets('never fabricates or alters a condition grade — renders no '
      'ConditionGradeIndicator-shaped content at all', (tester) async {
    await tester.pumpWidget(wrap(RestorationStatus.restored));

    expect(find.textContaining('/8'), findsNothing);
  });
}
