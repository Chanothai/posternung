import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/poster_condition_grade.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/poster/domain/entities/poster_detail.dart';
import 'package:posternung/features/poster/domain/entities/poster_image.dart';
import 'package:posternung/features/poster/domain/entities/poster_image_kind.dart';
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
    posterType: null,
    releaseRegion: null,
    releaseDateText: null,
    releaseDate: null,
    copyrightYear: null,
    sizeFormat: null,
    year: null,
    restorationStatus: null,
    restorationNote: null,
  );

  PosterDetail posterWithImages(List<PosterImage> images) => PosterDetail(
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
    images: images,
    createdAt: DateTime.utc(2024),
    posterType: null,
    releaseRegion: null,
    releaseDateText: null,
    releaseDate: null,
    copyrightYear: null,
    sizeFormat: null,
    year: null,
    restorationStatus: null,
    restorationNote: null,
  );

  /// Records every zoom-state change the controller publishes, which is what
  /// the app bar button and the screen's scroll physics both read.
  Future<List<bool>> pumpGallery(
    WidgetTester tester, {
    int imageCount = 2,
    PosterGalleryZoomController? controller,
  }) {
    final zoomController = controller ?? PosterGalleryZoomController();
    final events = <bool>[];
    zoomController.addListener(() => events.add(zoomController.isZoomed));
    addTearDown(zoomController.dispose);
    return tester
        .pumpWidget(
          MaterialApp(
            home: Scaffold(
              // Width-constrained and vertically unbounded, the way the
              // screen's ListView presents it — the gallery sizes its image
              // off the width, so an 800px-wide test surface would make a
              // 1200px-tall image and overflow.
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: PosterDetailImageGallery(
                    poster: poster(imageCount: imageCount),
                    zoomController: zoomController,
                  ),
                ),
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

  /// Two taps spaced between kDoubleTapMinTime (40ms) and kDoubleTapTimeout
  /// (300ms), so the pair really registers as a double tap rather than two
  /// separate ones.
  Future<void> doubleTap(WidgetTester tester) async {
    await tester.tap(find.byType(PageView));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();
  }

  testWidgets('a double tap zooms in and locks the carousel', (tester) async {
    final events = await pumpGallery(tester);

    await doubleTap(tester);

    expect(events, [true]);
    expect(pageViewPhysics(tester), isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('a second double tap zooms back out and re-arms the swipe', (
    tester,
  ) async {
    final events = await pumpGallery(tester);

    await doubleTap(tester);
    await doubleTap(tester);

    expect(events, [true, false]);
    expect(pageViewPhysics(tester), isNull);
  });

  testWidgets('a single tap does not zoom', (tester) async {
    final events = await pumpGallery(tester);

    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();

    expect(events, isEmpty);
    expect(pageViewPhysics(tester), isNull);
  });

  testWidgets('the controller drives the same zoom the gestures do', (
    tester,
  ) async {
    final controller = PosterGalleryZoomController();
    final events = await pumpGallery(tester, controller: controller);

    controller.toggle();
    await tester.pumpAndSettle();

    expect(events, [true]);
    expect(controller.isZoomed, isTrue);
    expect(pageViewPhysics(tester), isA<NeverScrollableScrollPhysics>());

    controller.toggle();
    await tester.pumpAndSettle();

    expect(events, [true, false]);
    expect(controller.isZoomed, isFalse);
    expect(pageViewPhysics(tester), isNull);
  });

  testWidgets('tapping the hint zooms — it is a control, not a caption', (
    tester,
  ) async {
    final events = await pumpGallery(tester);

    await tester.tap(find.text(AppStrings.posterDetailZoomHint));
    await tester.pumpAndSettle();

    expect(events, [true]);
    expect(pageViewPhysics(tester), isA<NeverScrollableScrollPhysics>());
  });

  testWidgets(
    'the page dots float inside the image frame, above the hint below it '
    '(ADR-0012 §D1 7:1067 moved them off their own row under the image)',
    (tester) async {
      await pumpGallery(tester);

      final hint = tester.getCenter(find.text(AppStrings.posterDetailZoomHint));
      // The dots are the only circular Containers in the tree.
      final dots = tester.getCenter(
        find.byWidgetPredicate((widget) {
          if (widget is! Container) return false;
          final decoration = widget.decoration;
          return decoration is BoxDecoration &&
              decoration.shape == BoxShape.circle;
        }).first,
      );

      // Dots now sit inside the image frame (a Positioned overlay near its
      // bottom edge), which is entirely above the hint text block that
      // follows the frame — the inverse of the pre-ADR-0012 layout, where
      // the dots were their own row below the hint.
      expect(dots.dy, lessThan(hint.dy));
    },
  );

  testWidgets('the hint says why to zoom, and rides along with the images', (
    tester,
  ) async {
    await pumpGallery(tester);
    expect(find.text(AppStrings.posterDetailZoomHint), findsOneWidget);
  });

  testWidgets('no images means no zoom affordance at all', (tester) async {
    await pumpGallery(tester, imageCount: 0);

    expect(find.byIcon(Icons.zoom_in), findsNothing);
    expect(find.text(AppStrings.posterDetailZoomHint), findsNothing);
  });

  testWidgets('an unzoomed swipe still changes page', (tester) async {
    await pumpGallery(tester);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(tester.widget<PageView>(find.byType(PageView)).controller?.page, 1);
  });

  group('ADR-0026 Amendment §A-D9 — the gallery actually calls '
      'orderPosterGalleryImages, not just a function that exists unused', () {
    // Reads the URL `Image.network` for the *first* rendered page — this
    // is what proves the ordering function is wired into `build()` and
    // not just unit-tested in isolation (code-critic's mutation "M4":
    // reverting `build()` to sort inline would leave this red while
    // `poster_gallery_order_test.dart` stays green).
    String firstRenderedImageUrl(WidgetTester tester) {
      final image = tester.widgetList<Image>(find.byType(Image)).first;
      return (image.image as NetworkImage).url;
    }

    testWidgets(
      'a wrong primary (isPrimary: true, kind: BACK) does not lead the '
      'carousel — the real FRONT image renders first instead',
      (tester) async {
        const wrongPrimary = PosterImage(
          id: 'wrong-primary',
          url: 'https://example.invalid/wrong-primary.jpg',
          isPrimary: true,
          kind: PosterImageKind.back,
          sortOrder: 100,
        );
        const front = PosterImage(
          id: 'front',
          url: 'https://example.invalid/front.jpg',
          isPrimary: false,
          kind: PosterImageKind.front,
          sortOrder: 0,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: PosterDetailImageGallery(
                    poster: posterWithImages([wrongPrimary, front]),
                    zoomController: PosterGalleryZoomController(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(
          firstRenderedImageUrl(tester),
          'https://example.invalid/front.jpg',
        );
        // The wrongly-primaried image is demoted, never dropped (D6
        // beats D9's old wording) — closed-world: both images still
        // build into the carousel.
        final pageView = tester.widget<PageView>(find.byType(PageView));
        expect(
          (pageView.childrenDelegate as SliverChildBuilderDelegate).childCount,
          2,
        );
      },
    );

    testWidgets('no FRONT image at all: every image still shows in a real '
        'carousel — no placeholder is shown when there are real images to '
        'display (D6 wins over the literal old D9 wording)', (tester) async {
      const back = PosterImage(
        id: 'back',
        url: 'https://example.invalid/back.jpg',
        isPrimary: false,
        kind: PosterImageKind.back,
        sortOrder: 100,
      );
      const defect = PosterImage(
        id: 'defect',
        url: 'https://example.invalid/defect.jpg',
        isPrimary: false,
        kind: PosterImageKind.defect,
        sortOrder: 200,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: PosterDetailImageGallery(
                  poster: posterWithImages([defect, back]),
                  zoomController: PosterGalleryZoomController(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(PageView), findsOneWidget);
      expect(firstRenderedImageUrl(tester), 'https://example.invalid/back.jpg');
      // Both images are built into the real carousel (not the
      // no-image `_ImagePlaceholder` path, which never builds a
      // `PageView` at all — see `build()`'s `urls.isEmpty` branch) —
      // closed-world: exactly 2 items, none dropped.
      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(
        (pageView.childrenDelegate as SliverChildBuilderDelegate).childCount,
        2,
      );
    });

    // H-1: the "wrong primary" case above always had its real FRONT image
    // already sort_order-first (sortOrder: 0), so it never actually
    // exercised rule 2b's hoist — it only exercised rule 2a's isPrimary
    // check. This one puts the real FRONT *behind* a BACK image by
    // sort_order, which is the only shape that proves the widget's build()
    // actually hoists, not just that it sorts by sort_order.
    testWidgets(
      'a FRONT image that sorts behind a BACK image by sort_order is still '
      'the first page rendered — proves the hoist, not just the sort',
      (tester) async {
        const backLeadsBySortOrder = PosterImage(
          id: 'back-leads-by-sort-order',
          url: 'https://example.invalid/back-leads.jpg',
          isPrimary: false,
          kind: PosterImageKind.back,
          sortOrder: 5,
        );
        const frontTrailsBySortOrder = PosterImage(
          id: 'front-trails-by-sort-order',
          url: 'https://example.invalid/front-trails.jpg',
          isPrimary: false,
          kind: PosterImageKind.front,
          sortOrder: 50,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: PosterDetailImageGallery(
                    poster: posterWithImages([
                      backLeadsBySortOrder,
                      frontTrailsBySortOrder,
                    ]),
                    zoomController: PosterGalleryZoomController(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(
          firstRenderedImageUrl(tester),
          'https://example.invalid/front-trails.jpg',
          reason:
              'plain sort_order order renders BACK first — the hoist '
              'must move FRONT to lead regardless',
        );
        final pageView = tester.widget<PageView>(find.byType(PageView));
        expect(
          (pageView.childrenDelegate as SliverChildBuilderDelegate).childCount,
          2,
        );
      },
    );
  });
}
