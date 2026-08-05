import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/poster_condition_grade.dart';
import 'package:posternung/core/catalog/release_region.dart';
import 'package:posternung/core/catalog/restoration_status.dart';
import 'package:posternung/core/catalog/size_format.dart';
import 'package:posternung/core/error/catalog_exception.dart';
import 'package:posternung/core/theme/app_colors.dart';
import 'package:posternung/features/poster/domain/entities/poster_detail.dart';
import 'package:posternung/features/poster/domain/entities/poster_image.dart';
import 'package:posternung/features/poster/domain/entities/poster_status.dart';
import 'package:posternung/features/poster/presentation/providers/poster_providers.dart';
import 'package:posternung/features/poster/presentation/screens/poster_detail_screen.dart';
import 'package:posternung/features/poster/presentation/widgets/poster_detail_image_gallery.dart';

/// Fake ViewModel that resolves/throws exactly what the test wants —
/// `build()` throwing is the framework-idiomatic way `AsyncNotifier`
/// surfaces a failure as `AsyncError` (unlike `AuthViewModel`'s
/// guard-wrapped action methods, which need `state = AsyncError(...)`
/// instead of a raw `throw` — see `add-feature-slice` skill §3).
class FakePosterDetailViewModel extends PosterDetailViewModel {
  FakePosterDetailViewModel(super.posterId, {this.detail, this.error});

  final PosterDetail? detail;
  final Object? error;
  int refreshCalls = 0;

  @override
  Future<PosterDetail> build() async {
    final error = this.error;
    if (error != null) throw error;
    final detail = this.detail;
    if (detail != null) return detail;
    // Neither set — stay loading forever (the "loading" state case).
    return Completer<PosterDetail>().future;
  }

  @override
  Future<void> refresh() async {
    refreshCalls++;
  }
}

PosterDetail _fullPoster({
  PosterStatus status = PosterStatus.available,
  // Non-null by default — the two existing fixtures (this one and
  // `_allNullFieldsPoster`) both used to set this to `null`, so the
  // has-a-grade rendering path (BR-05: price must always be paired with a
  // condition) was never exercised by any test at all.
  PosterConditionGrade? conditionGrade = PosterConditionGrade.veryGood,
  List<PosterImage> images = const [],
  String? studio = 'Warner Bros',
  // ADR-0011 (SCR-05 "แสดงฟิลด์ใหม่") — all default null so the pre-existing
  // fixture's subtitle/accordion behaviour (era_decade fallback, no
  // restoration badge) is unchanged unless a test opts in.
  int? year,
  ReleaseRegion? releaseRegion,
  SizeFormat? sizeFormat,
  RestorationStatus? restorationStatus,
  DateTime? releaseDate,
}) => PosterDetail(
  id: 'p1',
  title: 'Blade Runner',
  price: '450.00',
  status: status,
  conditionGrade: conditionGrade,
  eraDecade: 1982,
  studio: studio,
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
  releaseRegion: releaseRegion,
  releaseDateText: null,
  releaseDate: releaseDate,
  copyrightYear: null,
  sizeFormat: sizeFormat,
  year: year,
  restorationStatus: restorationStatus,
  restorationNote: null,
);

PosterDetail _allNullFieldsPoster() => PosterDetail(
  id: 'p2',
  title: 'Untitled Import',
  price: '0.00',
  status: PosterStatus.available,
  conditionGrade: null,
  eraDecade: null,
  studio: null,
  primaryImageUrl: null,
  tmdbId: null,
  size: null,
  description: null,
  isAuthenticated: false,
  authenticityNote: null,
  provenance: null,
  images: const [],
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

void main() {
  // The image gallery is a tall 2:3 AspectRatio block (a portrait poster
  // image, by design) — at the default 800x600 test surface it alone
  // exceeds the viewport, so content below it (title, price, sections)
  // never gets laid out and `find.text` can't see it. Same fix as
  // `home_screen_test.dart`'s `useTallSurface`.
  Future<void> useTallSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  /// The poster's title renders twice on the data state — as the listing
  /// heading in the list, and again in the app bar, where it stays fully
  /// transparent until the image scrolls past. Assertions about the heading
  /// have to say which one they mean.
  Finder listingTitle(String title) =>
      find.descendant(of: find.byType(ListView), matching: find.text(title));

  Widget wrap({PosterDetail? detail, Object? error}) {
    return ProviderScope(
      overrides: [
        posterDetailViewModelProvider.overrideWith2(
          (posterId) =>
              FakePosterDetailViewModel(posterId, detail: detail, error: error),
        ),
      ],
      child: const MaterialApp(home: PosterDetailScreen(posterId: 'p1')),
    );
  }

  testWidgets('loading state shows a spinner, no content', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Blade Runner'), findsNothing);
  });

  testWidgets('data state (all fields populated) renders every section', (
    tester,
  ) async {
    await useTallSurface(tester);
    await tester.pumpWidget(wrap(detail: _fullPoster()));
    await tester.pump();

    expect(listingTitle('Blade Runner'), findsOneWidget);
    expect(find.textContaining('1982'), findsOneWidget);
    expect(find.textContaining('Warner Bros'), findsOneWidget);
    // High #1 — Thai Baht, never a dollar sign.
    expect(find.text('฿450.00'), findsOneWidget);
    expect(find.text('\$450.00'), findsNothing);
    // High #2 / BR-05 — price is paired with a real condition grade (not
    // null in this fixture), position-on-scale format per ADR-0003.
    expect(find.text('Very Good (5/8)'), findsOneWidget);
    expect(
      find.text('มีชิ้นเดียว ของหายากที่เมื่อขายแล้วจะไม่กลับมาอีก'),
      findsOneWidget,
    );
    expect(find.text('ผ่านการตรวจสอบความแท้แล้ว'), findsOneWidget);
    expect(find.text('Verified by in-house expert.'), findsOneWidget);
    expect(find.text('รายละเอียด'), findsOneWidget); // accordion title
  });

  testWidgets('data state (every nullable field null) does not crash and hides '
      'sections/rows with no data', (tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(wrap(detail: _allNullFieldsPoster()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(listingTitle('Untitled Import'), findsOneWidget);
    // No era/studio → no subtitle line.
    expect(find.textContaining('•'), findsNothing);
    // is_authenticated: false → the "unverified" label, not "verified".
    expect(find.text('ยังไม่ผ่านการตรวจสอบความแท้'), findsOneWidget);
    // provenance/size/description all null → accordion has nothing to
    // show, so it's omitted entirely (D3: hide, don't show "-").
    expect(find.text('รายละเอียด'), findsNothing);
    // condition_grade null → the shared "unspecified" status, not a fake
    // grade and not nothing at all (BR-05) — see
    // `condition_grade_indicator_test.dart` for the widget's own coverage.
    expect(find.text('ไม่ระบุสภาพ'), findsOneWidget);
  });

  testWidgets(
    'sold state shows the sold banner with a way forward, not a crash',
    (tester) async {
      await useTallSurface(tester);
      await tester.pumpWidget(
        wrap(detail: _fullPoster(status: PosterStatus.sold)),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('โปสเตอร์ชิ้นนี้ถูกซื้อไปแล้ว'), findsOneWidget);
      expect(find.text('เลือกดูโปสเตอร์ชิ้นอื่น'), findsOneWidget);
      // Rest of the listing still renders below the banner.
      expect(listingTitle('Blade Runner'), findsOneWidget);
    },
  );

  testWidgets('404 not-found shows a dedicated screen, not a generic error, '
      'and surfaces the backend\'s own message (Medium #7)', (tester) async {
    await tester.pumpWidget(
      wrap(
        error: const CatalogException(
          code: 'POSTER_NOT_FOUND',
          // Deliberately distinct from the static
          // `AppStrings.posterDetailNotFoundTitle`/`...Body` copy, so this
          // test can prove the *backend's* message is what's shown, not a
          // static string that happens to read similarly.
          message: 'ไม่พบโปสเตอร์รหัส p1 ในระบบ',
        ),
      ),
    );
    await tester.pump();

    // Static title (always shown — the backend message is the body, not a
    // title replacement).
    expect(find.text('ไม่พบโปสเตอร์นี้'), findsOneWidget);
    // The backend's own message, not the static
    // `AppStrings.posterDetailNotFoundBody` copy.
    expect(find.text('ไม่พบโปสเตอร์รหัส p1 ในระบบ'), findsOneWidget);
    expect(
      find.text('โปสเตอร์นี้อาจถูกลบออกไปแล้ว หรือลิงก์ไม่ถูกต้อง'),
      findsNothing,
    );
    expect(find.text('กลับหน้าหลัก'), findsOneWidget);
    // No retry button on the not-found view.
    expect(find.text('ลองใหม่อีกครั้ง'), findsNothing);
  });

  testWidgets(
    'a generic failure (e.g. network_error) shows the retry error view with '
    'the backend\'s own message (Medium #7)',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          error: const CatalogException(
            code: 'network_error',
            message: 'เชื่อมต่อเครือข่ายไม่สำเร็จ',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('เกิดข้อผิดพลาด'), findsOneWidget);
      // The backend/exception's own message, not the static
      // `AppStrings.posterDetailErrorBody` copy.
      expect(find.text('เชื่อมต่อเครือข่ายไม่สำเร็จ'), findsOneWidget);
      expect(
        find.text('ไม่สามารถโหลดข้อมูลโปสเตอร์ได้ กรุณาลองใหม่อีกครั้ง'),
        findsNothing,
      );
      expect(find.text('ลองใหม่อีกครั้ง'), findsOneWidget);
    },
  );

  testWidgets(
    'a non-CatalogException failure falls back to the static error copy',
    (tester) async {
      await tester.pumpWidget(wrap(error: StateError('boom')));
      await tester.pump();

      expect(find.text('เกิดข้อผิดพลาด'), findsOneWidget);
      expect(
        find.text('ไม่สามารถโหลดข้อมูลโปสเตอร์ได้ กรุณาลองใหม่อีกครั้ง'),
        findsOneWidget,
      );
    },
  );

  group('AC-1 — image gallery (Medium #4)', () {
    const images = [
      PosterImage(
        id: 'img-1',
        url: 'https://example.invalid/1.jpg',
        isPrimary: true,
        sortOrder: 0,
      ),
      PosterImage(
        id: 'img-2',
        url: 'https://example.invalid/2.jpg',
        isPrimary: false,
        sortOrder: 1,
      ),
    ];

    Finder dotFinder() => find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      return decoration is BoxDecoration && decoration.shape == BoxShape.circle;
    });

    Color? dotColorAt(WidgetTester tester, int index) {
      final decoration = tester
          .widgetList<Container>(dotFinder())
          .elementAt(index)
          .decoration;
      return (decoration as BoxDecoration).color;
    }

    testWidgets(
      'multiple images render a pageable, zoomable carousel with a dot '
      'indicator per image',
      (tester) async {
        await useTallSurface(tester);
        await tester.pumpWidget(wrap(detail: _fullPoster(images: images)));
        await tester.pump();

        expect(find.byType(PosterDetailImageGallery), findsOneWidget);
        expect(find.byType(PageView), findsOneWidget);
        expect(find.byType(InteractiveViewer), findsWidgets);
        expect(dotFinder(), findsNWidgets(2));
      },
    );

    testWidgets('swiping the carousel actually pages — first dot starts '
        'highlighted, second highlights after a swipe', (tester) async {
      await useTallSurface(tester);
      await tester.pumpWidget(wrap(detail: _fullPoster(images: images)));
      await tester.pump();

      expect(dotColorAt(tester, 0), AppColors.accent);
      expect(dotColorAt(tester, 1), isNot(AppColors.accent));

      await tester.drag(find.byType(PageView), const Offset(-800, 0));
      await tester.pumpAndSettle();

      expect(dotColorAt(tester, 0), isNot(AppColors.accent));
      expect(dotColorAt(tester, 1), AppColors.accent);
    });

    testWidgets('a single image shows no dot indicator at all', (tester) async {
      await useTallSurface(tester);
      await tester.pumpWidget(
        wrap(detail: _fullPoster(images: [images.first])),
      );
      await tester.pump();

      expect(find.byType(PageView), findsOneWidget);
      expect(dotFinder(), findsNothing);
    });

    // A zoomed image must keep the one-finger pan for itself, so the outer
    // list has to stand down too — not just the PageView (see
    // PosterDetailImageGallery's gesture-arena note). This pins the wiring
    // only; it cannot prove the arena outcome on a real touch stream.
    testWidgets('zooming an image stops the page from scrolling under it', (
      tester,
    ) async {
      await useTallSurface(tester);
      await tester.pumpWidget(wrap(detail: _fullPoster(images: images)));
      await tester.pump();

      ScrollPhysics? listPhysics() =>
          tester.widget<ListView>(find.byType(ListView)).physics;

      expect(listPhysics(), isA<AlwaysScrollableScrollPhysics>());

      final centre = tester.getCenter(find.byType(PageView));
      final left = await tester.startGesture(centre - const Offset(20, 0));
      final right = await tester.startGesture(centre + const Offset(20, 0));
      await tester.pump();
      await left.moveTo(centre - const Offset(100, 0));
      await right.moveTo(centre + const Offset(100, 0));
      await tester.pump();
      await left.up();
      await right.up();
      await tester.pumpAndSettle();

      expect(listPhysics(), isA<NeverScrollableScrollPhysics>());
    });
  });

  group('app bar zoom action', () {
    const images = [
      PosterImage(
        id: 'img-1',
        url: 'https://example.invalid/1.jpg',
        isPrimary: true,
        sortOrder: 0,
      ),
    ];

    Finder inBar(Finder finder) =>
        find.descendant(of: find.byType(AppBar), matching: finder);

    testWidgets('shares the bar with the title rather than replacing it', (
      tester,
    ) async {
      await useTallSurface(tester);
      await tester.pumpWidget(wrap(detail: _fullPoster(images: images)));
      await tester.pump();

      expect(inBar(find.byIcon(Icons.zoom_in)), findsOneWidget);
      expect(inBar(find.text('Blade Runner')), findsOneWidget);
      expect(inBar(find.byIcon(Icons.arrow_back)), findsOneWidget);
    });

    testWidgets('zooms the gallery and locks the list behind it', (
      tester,
    ) async {
      await useTallSurface(tester);
      await tester.pumpWidget(wrap(detail: _fullPoster(images: images)));
      await tester.pump();

      await tester.tap(inBar(find.byIcon(Icons.zoom_in)));
      await tester.pumpAndSettle();

      // The glyph reports the state, so it has to follow it.
      expect(inBar(find.byIcon(Icons.zoom_out)), findsOneWidget);
      expect(
        tester.widget<ListView>(find.byType(ListView)).physics,
        isA<NeverScrollableScrollPhysics>(),
      );
    });

    testWidgets('absent when the poster has no image to zoom', (tester) async {
      await useTallSurface(tester);
      await tester.pumpWidget(wrap(detail: _allNullFieldsPoster()));
      await tester.pump();

      expect(find.byIcon(Icons.zoom_in), findsNothing);
    });
  });

  testWidgets(
    'a blank studio shows the era alone, with no stranded separator',
    (tester) async {
      await useTallSurface(tester);
      // Blank, not null — that is what the wire actually returns for some rows,
      // and it used to render as "1982s •".
      await tester.pumpWidget(wrap(detail: _fullPoster(studio: '')));
      await tester.pump();

      expect(find.text('1982s'), findsOneWidget);
      expect(find.textContaining('•'), findsNothing);
    },
  );

  group('ADR-0011 §D4′/§D9 — subtitle with the 9 new fields', () {
    testWidgets('year replaces era_decade in the subtitle when present', (
      tester,
    ) async {
      await useTallSurface(tester);
      await tester.pumpWidget(wrap(detail: _fullPoster(year: 1941)));
      await tester.pump();

      // Full-line match, not textContaining — the whole point is that
      // "1982s" is gone, not merely that "1941" showed up somewhere else
      // on the page.
      expect(find.text('1941 • Warner Bros'), findsOneWidget);
      expect(find.textContaining('1982s'), findsNothing);
    });

    testWidgets('no year — falls back to the original era_decade behaviour', (
      tester,
    ) async {
      await useTallSurface(tester);
      await tester.pumpWidget(wrap(detail: _fullPoster()));
      await tester.pump();

      expect(find.text('1982s • Warner Bros'), findsOneWidget);
    });

    // code-critic round 1 H2 — the previous version of these two tests used
    // `find.textContaining(...)`, which stayed green even after removing
    // the `region != ReleaseRegion.unknown` guard from `_subtitle` (proven
    // by mutation). Both assertions below are now exact full-line matches
    // built from the enums' own `.label` — never the wire value — so a
    // leaked prefix changes the string and the match fails.
    testWidgets(
      'a real release_region prefixes size_format in the subtitle exactly '
      'once',
      (tester) async {
        await useTallSurface(tester);
        await tester.pumpWidget(
          wrap(
            detail: _fullPoster(
              year: 1941,
              releaseRegion: ReleaseRegion.us,
              sizeFormat: SizeFormat.oneSheet,
            ),
          ),
        );
        await tester.pump();

        expect(
          find.text(
            '1941 • ${ReleaseRegion.us.label} ${SizeFormat.oneSheet.label} '
            '• Warner Bros',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ADR-0011 §D9 — release_region UNKNOWN never reaches the subtitle: '
      'size_format shows plain, with no region prefix and no leaked '
      '"checked, couldn\'t tell" text at all',
      (tester) async {
        await useTallSurface(tester);
        await tester.pumpWidget(
          wrap(
            detail: _fullPoster(
              year: 1941,
              releaseRegion: ReleaseRegion.unknown,
              sizeFormat: SizeFormat.oneSheet,
            ),
          ),
        );
        await tester.pump();

        // Exact full-line match: catches a leaked prefix in *any* form,
        // not just the literal wire value "UNKNOWN" (which the UI was
        // never going to render as-is — it renders the enum's Thai label).
        expect(
          find.text('1941 • ${SizeFormat.oneSheet.label} • Warner Bros'),
          findsOneWidget,
        );
        expect(find.textContaining(ReleaseRegion.unknown.label), findsNothing);
      },
    );

    testWidgets('size_format null — no format segment in the subtitle at '
        'all, region or not', (tester) async {
      await useTallSurface(tester);
      await tester.pumpWidget(
        wrap(detail: _fullPoster(year: 1941, releaseRegion: ReleaseRegion.us)),
      );
      await tester.pump();

      // Exact full-line match — no stray "US" or "•" left behind either.
      expect(find.text('1941 • Warner Bros'), findsOneWidget);
    });

    // 🔴 GATE 3 open question, pinned not endorsed (per the coordinator's
    // "ห้ามแก้รอบนี้" note) — D4′ puts `size_format` in the subtitle, D7
    // says `UNKNOWN` must be visible, and D9 only resolves the
    // region↔size_format interaction for `release_region`'s own UNKNOWN,
    // not `size_format`'s. Today that combination produces a plain Thai
    // label in the subtitle. This test exists only to catch an
    // *accidental* change to that output before GATE 3 decides the real
    // answer — passing it is not a design endorsement.
    testWidgets('size_format UNKNOWN today renders its own label plain in the '
        'subtitle (current behaviour only — not a design decision, see '
        'GATE 3)', (tester) async {
      await useTallSurface(tester);
      await tester.pumpWidget(
        wrap(detail: _fullPoster(year: 1941, sizeFormat: SizeFormat.unknown)),
      );
      await tester.pump();

      expect(
        find.text('1941 • ${SizeFormat.unknown.label} • Warner Bros'),
        findsOneWidget,
      );
    });
  });

  group('ADR-0011 §D2′ (GATE 3) — restoration badge placement', () {
    testWidgets(
      'RESTORED shows the fact badge on its own line under price/grade',
      (tester) async {
        await useTallSurface(tester);
        await tester.pumpWidget(
          wrap(
            detail: _fullPoster(restorationStatus: RestorationStatus.restored),
          ),
        );
        await tester.pump();

        expect(find.text('ผ่านการบูรณะ'), findsOneWidget);
      },
    );

    testWidgets('LINEN_BACKED shows its own fact badge', (tester) async {
      await useTallSurface(tester);
      await tester.pumpWidget(
        wrap(
          detail: _fullPoster(restorationStatus: RestorationStatus.linenBacked),
        ),
      );
      await tester.pump();

      expect(find.text('ติดผ้าใบ (linen-backed)'), findsOneWidget);
    });

    // §Amendment (2)/D2′, decided at GATE 3 — NONE, UNKNOWN, and null must
    // **all three** stay silent here, covered together on purpose. This is
    // a **negative** assertion left in place, not a deleted test: round 1
    // of this feature had UNKNOWN render its own fact badge (on the theory
    // that ADR-0011 §D7's `NULL`≠`UNKNOWN` rule applied to this badge too);
    // GATE 3 overturned that and made `restoration_status` an explicit,
    // narrow exception to §D7 (revised AC-10: "RESTORED หรือ LINEN_BACKED
    // เท่านั้น"). Keeping the assertion inverted — rather than just removing
    // the old "UNKNOWN shows" test — is what would catch anyone re-adding
    // `unknown` to `PosterRestorationBadge.showsFor` later.
    for (final silent in [
      RestorationStatus.none,
      RestorationStatus.unknown,
      null,
    ]) {
      testWidgets('$silent shows no badge at all and does not crash '
          "(today's real state for all 117 SIT rows is null)", (tester) async {
        await useTallSurface(tester);
        await tester.pumpWidget(
          wrap(detail: _fullPoster(restorationStatus: silent)),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('ผ่านการบูรณะ'), findsNothing);
        expect(find.text('ติดผ้าใบ (linen-backed)'), findsNothing);
        expect(find.text('ตรวจแล้วระบุไม่ได้'), findsNothing);
      });
    }
  });

  group('ADR-0011 §D3 / AC-8 — release_date is parsed but never shown', () {
    testWidgets(
      'release_date has a value — still never rendered anywhere on screen, '
      'even though release_date_text is the field actually shown',
      (tester) async {
        await useTallSurface(tester);
        await tester.pumpWidget(
          wrap(detail: _fullPoster(releaseDate: DateTime.utc(2021, 6, 15))),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('2021-06-15'), findsNothing);
        expect(find.textContaining('15/6/2021'), findsNothing);
        expect(find.textContaining('June 15'), findsNothing);
        expect(find.textContaining('2021-06-15 00:00:00'), findsNothing);
      },
    );
  });

  group('collapsing app bar title', () {
    /// The bar's copy of the title — the one outside the list.
    double barTitleOpacity(WidgetTester tester) {
      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Blade Runner'),
          ),
          matching: find.byType(Opacity),
        ),
      );
      return opacity.opacity;
    }

    testWidgets('starts fully transparent so the poster leads on its own', (
      tester,
    ) async {
      await useTallSurface(tester);
      await tester.pumpWidget(wrap(detail: _fullPoster()));
      await tester.pump();

      expect(barTitleOpacity(tester), 0);
      // The back button is there the whole time, faded title or not.
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    // Deliberately the *default* surface, not `useTallSurface`: a 2400pt-tall
    // viewport leaves this listing with nothing to scroll at all, and the
    // interesting case is the ordinary one where the image is taller than the
    // scroll the content affords (see `_fadeProgress`'s maxScrollExtent cap).
    testWidgets('fades in as the poster scrolls away', (tester) async {
      await tester.pumpWidget(wrap(detail: _fullPoster()));
      await tester.pump();

      expect(barTitleOpacity(tester), 0);

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(barTitleOpacity(tester), 1);
    });

    testWidgets('stays hidden when the listing does not scroll at all', (
      tester,
    ) async {
      // Tall enough that everything fits — the poster never leaves, so the
      // bar has no reason to name it.
      await useTallSurface(tester);
      await tester.pumpWidget(wrap(detail: _fullPoster()));
      await tester.pumpAndSettle();

      expect(barTitleOpacity(tester), 0);
    });

    testWidgets('no title at all while loading or failed', (tester) async {
      await tester.pumpWidget(
        wrap(
          error: const CatalogException(
            code: 'network_error',
            message: 'ต่อเน็ตไม่ได้',
          ),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.byType(Text)),
        findsNothing,
      );
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  group('AC-5 — refresh on foreground resume (Medium #5)', () {
    testWidgets('resuming the app from the background triggers a refresh', (
      tester,
    ) async {
      await useTallSurface(tester);
      final viewModel = FakePosterDetailViewModel('p1', detail: _fullPoster());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            posterDetailViewModelProvider.overrideWith2(
              (posterId) => viewModel,
            ),
          ],
          child: const MaterialApp(home: PosterDetailScreen(posterId: 'p1')),
        ),
      );
      await tester.pump();

      expect(viewModel.refreshCalls, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(viewModel.refreshCalls, 1);
    });

    testWidgets('going to the background does not itself trigger a refresh', (
      tester,
    ) async {
      await useTallSurface(tester);
      final viewModel = FakePosterDetailViewModel('p1', detail: _fullPoster());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            posterDetailViewModelProvider.overrideWith2(
              (posterId) => viewModel,
            ),
          ],
          child: const MaterialApp(home: PosterDetailScreen(posterId: 'p1')),
        ),
      );
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(viewModel.refreshCalls, 0);
    });

    testWidgets('pull-to-refresh triggers a refresh', (tester) async {
      await useTallSurface(tester);
      final viewModel = FakePosterDetailViewModel('p1', detail: _fullPoster());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            posterDetailViewModelProvider.overrideWith2(
              (posterId) => viewModel,
            ),
          ],
          child: const MaterialApp(home: PosterDetailScreen(posterId: 'p1')),
        ),
      );
      await tester.pump();

      expect(viewModel.refreshCalls, 0);

      // Mirrors Flutter's own `RefreshIndicator` test pattern (framework
      // `refresh_indicator_test.dart`) — a fling on scrollable content
      // followed by explicit pumps for each of the indicator's animation
      // phases (scroll settle → indicator settle → indicator hide).
      // `pumpAndSettle()` doesn't reliably resolve all three here.
      //
      // `RefreshIndicator` only "arms" (and actually calls `onRefresh`)
      // once the drag covers ~25% of the scrollable's height
      // (`_kDragContainerExtentPercentage` in the framework source) — on
      // `useTallSurface`'s 2400px-tall viewport that's ~600px, so the
      // 300px offset that's plenty on a normal-sized screen silently
      // undershoots here and the indicator just cancels instead of
      // refreshing. 900px clears that threshold with margin.
      await tester.fling(
        listingTitle('Blade Runner'),
        const Offset(0, 900),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(viewModel.refreshCalls, 1);
    });
  });
}
