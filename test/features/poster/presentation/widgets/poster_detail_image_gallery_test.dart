import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/poster_condition_grade.dart';
import 'package:posternung/features/poster/domain/entities/poster_detail.dart';
import 'package:posternung/features/poster/domain/entities/poster_image.dart';
import 'package:posternung/features/poster/domain/entities/poster_status.dart';
import 'package:posternung/features/poster/presentation/widgets/poster_detail_image_gallery.dart';

/// ⚠️ These tests pin the gallery's **zoom state machine** — that the flag
/// flips and that the `PageView`'s physics follows it. They do **not** prove
/// the gesture conflict is fixed: the defect lives in gesture-arena
/// resolution against a real touch stream, which the test binding does not
/// reproduce. Only device verification closes AC-1. See this feature's
/// `CLAUDE.md`.
void main() {
  PosterDetail poster({int imageCount = 2}) => PosterDetail(
    id: 'p1',
    title: 'Blade Runner',
    price: '450.00',
    status: PosterStatus.available,
    conditionGrade: PosterConditionGrade.veryGood,
    eraDecade: 1982,
    studio: 'Warner Bros',
    primaryImageUrl: null,
    tmdbId: 78,
    size: '27x41 in',
    description: 'US theatrical one-sheet.',
    isAuthenticated: true,
    authenticityNote: 'Verified by in-house expert.',
    provenance: 'Estate collection, Los Angeles.',
    images: [
      for (var i = 0; i < imageCount; i++)
        PosterImage(
          id: 'img$i',
          url: 'https://example.test/$i.jpg',
          isPrimary: i == 0,
          sortOrder: i,
        ),
    ],
    createdAt: DateTime.utc(2024),
  );

  Future<List<bool>> pumpGallery(WidgetTester tester, {int imageCount = 2}) {
    final events = <bool>[];
    return tester
        .pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PosterDetailImageGallery(
                poster: poster(imageCount: imageCount),
                onZoomChanged: events.add,
              ),
            ),
          ),
        )
        .then((_) => events);
  }

  ScrollPhysics? pageViewPhysics(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).physics;

  /// Drives a two-finger pinch centred on the image, spreading the pointers
  /// from [from] to [to] logical pixels apart.
  Future<void> pinch(
    WidgetTester tester, {
    required double from,
    required double to,
  }) async {
    final centre = tester.getCenter(find.byType(PageView));
    final start = Offset(from / 2, 0);
    final end = Offset(to / 2, 0);

    final left = await tester.startGesture(centre - start);
    final right = await tester.startGesture(centre + start);
    await tester.pump();
    await left.moveTo(centre - end);
    await right.moveTo(centre + end);
    await tester.pump();
    await left.up();
    await right.up();
    await tester.pumpAndSettle();
  }

  testWidgets('leaves the PageView swipeable while unzoomed', (tester) async {
    await pumpGallery(tester);

    expect(pageViewPhysics(tester), isNull);
  });

  testWidgets('stops the PageView once the image is zoomed in', (tester) async {
    final events = await pumpGallery(tester);

    await pinch(tester, from: 40, to: 200);

    expect(events, [true]);
    expect(pageViewPhysics(tester), isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('restores swiping once the image is zoomed back out', (
    tester,
  ) async {
    final events = await pumpGallery(tester);

    await pinch(tester, from: 40, to: 200);
    await pinch(tester, from: 200, to: 40);

    expect(events, [true, false]);
    expect(pageViewPhysics(tester), isNull);
  });

  testWidgets('a double tap leaves the zoom state untouched', (tester) async {
    final events = await pumpGallery(tester);

    await tester.tap(find.byType(PageView));
    // Between kDoubleTapMinTime (40ms) and kDoubleTapTimeout (300ms), so the
    // pair really is a double tap rather than two separate ones.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();

    expect(events, isEmpty);
    expect(pageViewPhysics(tester), isNull);
  });

  testWidgets('an unzoomed swipe still changes page', (tester) async {
    await pumpGallery(tester);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(tester.widget<PageView>(find.byType(PageView)).controller?.page, 1);
  });
}
