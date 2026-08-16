import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/features/poster/domain/entities/poster_image.dart';
import 'package:posternung/features/poster/domain/entities/poster_image_kind.dart';
import 'package:posternung/features/poster/presentation/poster_gallery_order.dart';

/// Every permutation of a list, iteratively (Heap's algorithm) — used by
/// AC-4's "random import order → stable gallery order" test. 5 images gives
/// 120 permutations, comfortably inside "several dozen at minimum" and fast
/// enough to run on every `flutter test`.
List<List<T>> _permutations<T>(List<T> items) {
  final result = <List<T>>[];
  void heap(int k, List<T> arr) {
    if (k == 1) {
      result.add(List<T>.from(arr));
      return;
    }
    for (var i = 0; i < k; i++) {
      heap(k - 1, arr);
      if (k.isEven) {
        final tmp = arr[i];
        arr[i] = arr[k - 1];
        arr[k - 1] = tmp;
      } else {
        final tmp = arr[0];
        arr[0] = arr[k - 1];
        arr[k - 1] = tmp;
      }
    }
  }

  heap(items.length, List<T>.from(items));
  return result;
}

void main() {
  // ADR-0026 §D5's real bands: FRONT 0-99, BACK 100-199, DEFECT 200-299.
  const front0 = PosterImage(
    id: 'front-0',
    url: 'https://example.invalid/front-0.jpg',
    isPrimary: true,
    sortOrder: 0,
    kind: PosterImageKind.front,
  );
  const front1 = PosterImage(
    id: 'front-1',
    url: 'https://example.invalid/front-1.jpg',
    isPrimary: false,
    sortOrder: 1,
    kind: PosterImageKind.front,
  );
  const back0 = PosterImage(
    id: 'back-0',
    url: 'https://example.invalid/back-0.jpg',
    isPrimary: false,
    sortOrder: 100,
    kind: PosterImageKind.back,
  );
  const back1 = PosterImage(
    id: 'back-1',
    url: 'https://example.invalid/back-1.jpg',
    isPrimary: false,
    sortOrder: 101,
    kind: PosterImageKind.back,
  );
  const defect0 = PosterImage(
    id: 'defect-0',
    url: 'https://example.invalid/defect-0.jpg',
    isPrimary: false,
    sortOrder: 200,
    kind: PosterImageKind.defect,
  );

  group('AC-4 — import order must not change the displayed order', () {
    final wellFormed = [front0, front1, back0, back1, defect0];
    const expectedIds = ['front-0', 'front-1', 'back-0', 'back-1', 'defect-0'];

    test('every permutation of a well-formed set (multiple FRONT/BACK/DEFECT) '
        'produces the exact same FRONT…→BACK…→DEFECT… order, and every image '
        'survives (closed-world: output count == input count)', () {
      final permutations = _permutations(wellFormed);
      expect(permutations.length, 120);

      for (final permutation in permutations) {
        final ordered = orderPosterGalleryImages(permutation);

        expect(
          ordered.length,
          wellFormed.length,
          reason: 'no image may be dropped for permutation $permutation',
        );
        expect(ordered.map((i) => i.id).toList(), expectedIds);
      }
    });
  });

  group('sorting', () {
    test('sorts by sort_order ascending when there is no hoist candidate '
        'at all (no FRONT present)', () {
      final ordered = orderPosterGalleryImages([defect0, back0, back1]);

      expect(ordered.map((i) => i.id).toList(), [
        'back-0',
        'back-1',
        'defect-0',
      ]);
    });

    // L-1: a 2-element version of this test passed identically with or
    // without the `a.key.compareTo(b.key)` tie-break, because `List.sort`
    // uses insertion sort (stable by accident) for lists this short — it
    // only switches to an unstable sort past a length-32 threshold, so the
    // assertion was true before the tie-break code ran at all. 40 elements
    // is past that 32-element threshold, which is what actually exercises
    // the code this test claims to protect — confirmed by mutation
    // (removing the tie-break turns this red on 40 elements; see verify
    // report). Anything at or below 32 puts it straight back to vacuous.
    test('ties on sort_order keep their original relative order (stable), '
        'past the length where List.sort stops being accidentally stable', () {
      // All `back` kind so no FRONT hoist can interfere with what this test
      // isolates: relative order among elements that tie on sort_order.
      final images = List<PosterImage>.generate(
        40,
        (i) => PosterImage(
          id: 'tie-$i',
          url: 'https://example.invalid/tie-$i.jpg',
          isPrimary: false,
          sortOrder: 5,
          kind: PosterImageKind.back,
        ),
      );
      final expectedIds = images.map((i) => i.id).toList();

      expect(
        orderPosterGalleryImages(images).map((i) => i.id).toList(),
        expectedIds,
      );

      // And reversed input must come back out reversed-then-unstirred —
      // i.e. still exactly the reversed input order, not re-sorted to the
      // forward order above (which a merge of already-sorted runs could
      // produce by coincidence on some inputs).
      final reversedImages = images.reversed.toList();
      expect(
        orderPosterGalleryImages(reversedImages).map((i) => i.id).toList(),
        reversedImages.map((i) => i.id).toList(),
      );
    });
  });

  group('H-1 — hoisting a FRONT image that is not already sort_order-first '
      '(every fixture elsewhere in this file has FRONT at sortOrder 0, so '
      'hoistIndex was always 0 and the "if (hoistIndex <= 0) return ordered" '
      'early-exit skipped the hoist block before it ever ran — deleting the '
      'whole rule-2b block left this class of input unprotected; confirmed '
      'by mutation, see verify report)', () {
    test('a non-primary FRONT sorted after a BACK by sort_order is still '
        'hoisted to lead the gallery', () {
      const backLeadsBySortOrder = PosterImage(
        id: 'back-leads-by-sort-order',
        url: 'https://example.invalid/back.jpg',
        isPrimary: false,
        kind: PosterImageKind.back,
        sortOrder: 5,
      );
      const frontTrailsBySortOrder = PosterImage(
        id: 'front-trails-by-sort-order',
        url: 'https://example.invalid/front.jpg',
        isPrimary: false,
        kind: PosterImageKind.front,
        sortOrder: 50,
      );

      final ordered = orderPosterGalleryImages([
        backLeadsBySortOrder,
        frontTrailsBySortOrder,
      ]);

      expect(
        ordered.map((i) => i.id).toList(),
        ['front-trails-by-sort-order', 'back-leads-by-sort-order'],
        reason:
            'plain sort_order order is [back, front] — rule 2b must '
            'still move the FRONT to lead even though it is not '
            'sort_order-first',
      );
    });
  });

  group('M-1 — sort_order, not kind, owns the order of images the hoist '
      'does not touch (ADR-0026 §D5 deliberately rejected a second, '
      'kind-based ordering rule — see this file\'s own doc comment on '
      '"why rule 4... matters"). Deliberately disjoint fixture ids/shape '
      'from the H-1 group above: H-1 asserts the hoist happens at all, this '
      'asserts the order left behind after a hoist that needed no rule-2b '
      'work (FRONT already primary and already sort_order-first) — a '
      'kind-rank comparator would still corrupt the untouched tail, which '
      'is what this catches.', () {
    test('DEFECT (lower sort_order) stays ahead of BACK (higher sort_order) '
        'even though kind rank (FRONT→BACK→DEFECT) would put BACK first', () {
      const frontLeading = PosterImage(
        id: 'front-leading',
        url: 'https://example.invalid/front.jpg',
        isPrimary: true,
        kind: PosterImageKind.front,
        sortOrder: 0,
      );
      const defectLowSortOrder = PosterImage(
        id: 'defect-low-sort-order',
        url: 'https://example.invalid/defect.jpg',
        isPrimary: false,
        kind: PosterImageKind.defect,
        sortOrder: 5,
      );
      const backHighSortOrder = PosterImage(
        id: 'back-high-sort-order',
        url: 'https://example.invalid/back.jpg',
        isPrimary: false,
        kind: PosterImageKind.back,
        sortOrder: 50,
      );

      // Shuffled on input on purpose — AC-4 already covers that import
      // order doesn't matter; this test is about the *rule*, so the input
      // order here is incidental to what it proves.
      final ordered = orderPosterGalleryImages([
        backHighSortOrder,
        frontLeading,
        defectLowSortOrder,
      ]);

      expect(
        ordered.map((i) => i.id).toList(),
        ['front-leading', 'defect-low-sort-order', 'back-high-sort-order'],
        reason:
            'kind rank would yield [front, back, defect]; sort_order '
            '(5 < 50) must instead yield [front, defect, back]',
      );
    });
  });

  group('AC-14 (ค) — fail-closed when the backend sends bad data '
      '(ADR-0026 Amendment §A-D9 (2))', () {
    // 🔴 Deliberately `isPrimary: false` here, unlike the shared `front0`
    // fixture above — a test that reused `front0` (`isPrimary: true`) would
    // pass by accident even if the hoist rule dropped the `kind == front`
    // condition entirely (mutation M1), because `front0` would still win
    // the plain-`isPrimary` scan first in `sort_order` order. The real
    // FRONT image here has to be *not* primary, so that only a rule that
    // actually checks `kind == front` for the hoist decision can find it.
    const realFrontNotPrimary = PosterImage(
      id: 'real-front-not-primary',
      url: 'https://example.invalid/real-front.jpg',
      isPrimary: false,
      kind: PosterImageKind.front,
      sortOrder: 1,
    );

    test('a wrong primary (isPrimary: true, kind: BACK) is demoted, not '
        'hoisted, and — critically — still present in the output', () {
      const wrongPrimary = PosterImage(
        id: 'wrong-primary-back',
        url: 'https://example.invalid/wrong.jpg',
        isPrimary: true,
        kind: PosterImageKind.back,
        sortOrder: 100,
      );
      final ordered = orderPosterGalleryImages([
        wrongPrimary,
        realFrontNotPrimary,
        defect0,
      ]);

      expect(
        ordered.first.id,
        'real-front-not-primary',
        reason: 'the real FRONT leads',
      );
      expect(
        ordered.map((i) => i.id).toSet(),
        {'wrong-primary-back', 'real-front-not-primary', 'defect-0'},
        reason: 'the wrongly-primaried image must not be dropped',
      );
      expect(ordered.length, 3);
    });

    test('a wrong primary (isPrimary: true, kind: DEFECT) is demoted, not '
        'hoisted, and still present in the output', () {
      const wrongPrimary = PosterImage(
        id: 'wrong-primary-defect',
        url: 'https://example.invalid/wrong.jpg',
        isPrimary: true,
        kind: PosterImageKind.defect,
        sortOrder: 200,
      );
      final ordered = orderPosterGalleryImages([
        wrongPrimary,
        realFrontNotPrimary,
        back0,
      ]);

      expect(ordered.first.id, 'real-front-not-primary');
      expect(ordered.map((i) => i.id).toSet(), {
        'wrong-primary-defect',
        'real-front-not-primary',
        'back-0',
      });
      expect(ordered.length, 3);
    });

    test('no FRONT image at all: every image still shows, in sort_order order '
        '— D6 wins over the literal old D9 wording, no images dropped', () {
      final ordered = orderPosterGalleryImages([defect0, back0]);

      expect(ordered.map((i) => i.id).toList(), ['back-0', 'defect-0']);
      expect(ordered.length, 2);
    });

    test('every image has kind == null (simulated pre-ADR-0026 backend/'
        'rollback): does not crash, shows every image, hoists nothing', () {
      const nullKindA = PosterImage(
        id: 'null-a',
        url: 'https://example.invalid/a.jpg',
        isPrimary: true,
        sortOrder: 0,
      );
      const nullKindB = PosterImage(
        id: 'null-b',
        url: 'https://example.invalid/b.jpg',
        isPrimary: false,
        sortOrder: 1,
      );

      expect(
        () => orderPosterGalleryImages([nullKindB, nullKindA]),
        returnsNormally,
      );
      final ordered = orderPosterGalleryImages([nullKindB, nullKindA]);

      // sort_order order, unaffected by the (unrecognized) isPrimary/kind
      // combination — nothing to hoist because kind is never `front`.
      expect(ordered.map((i) => i.id).toList(), ['null-a', 'null-b']);
      expect(ordered.length, 2);
    });
  });
}
