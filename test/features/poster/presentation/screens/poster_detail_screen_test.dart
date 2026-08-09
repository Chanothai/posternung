import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/poster_condition_grade.dart';
import 'package:posternung/core/catalog/release_region.dart';
import 'package:posternung/core/catalog/restoration_status.dart';
import 'package:posternung/core/catalog/size_format.dart';
import 'package:posternung/core/error/catalog_exception.dart';
import 'package:posternung/core/router/app_router.dart';
import 'package:posternung/core/router/app_routes.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/core/theme/app_colors.dart';
import 'package:posternung/core/widgets/gradient_background.dart';
import 'package:posternung/features/poster/domain/entities/poster_detail.dart';
import 'package:posternung/features/poster/domain/entities/poster_image.dart';
import 'package:posternung/features/poster/domain/entities/poster_status.dart';
import 'package:posternung/features/poster/presentation/providers/poster_providers.dart';
import '../../../../support/backend_envelope_fixture.dart';
import '../../../../support/router_harness.dart';
import 'package:posternung/features/poster/presentation/widgets/poster_detail_image_gallery.dart';
import 'package:posternung/features/poster/presentation/widgets/poster_details_accordion.dart';

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
      child: routedApp(
        location: AppRoutes.posterDetail('p1'),
        routes: appRoutes,
      ),
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
    // 🔴 ADR-0014 D1/D27 — assertion **กลับด้าน** เมื่อ 2026-08-07: เดิมข้อนี้
    // ยืนยันว่าป้าย 'ผ่านการตรวจสอบความแท้แล้ว' กับ `authenticityNote` ของ fixture
    // ต้องขึ้นจอ · ทั้งบล็อกถูกถอดออกแล้ว จึงต้องยืนยันว่า **ไม่มี** แทน
    // ทั้งที่ fixture ยังตั้ง `isAuthenticated: true` + note ไว้เหมือนเดิม —
    // เงื่อนไขฝั่งข้อมูลไม่เปลี่ยน สิ่งที่เปลี่ยนคือหน้าจอเลิกอ้าง
    expect(find.text('ผ่านการตรวจสอบความแท้แล้ว'), findsNothing);
    expect(find.text('ความถูกต้องแท้จริง'), findsNothing);
    expect(find.text('Verified by in-house expert.'), findsNothing);
    expect(find.byIcon(Icons.gpp_good_outlined), findsNothing);
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
    // 🔴 ADR-0014 D1/D27 — `is_authenticated: false` เคยทำให้ป้าย
    // 'ยังไม่ผ่านการตรวจสอบความแท้' ขึ้นจอ · **ฝั่งลบก็ถูกถอดเหมือนกัน** เพราะ
    // มันยืนยันว่ามี "การตรวจสอบความแท้" ที่ร้านทำอยู่จริงพอ ๆ กับฝั่งบวก
    expect(find.text('ยังไม่ผ่านการตรวจสอบความแท้'), findsNothing);
    expect(find.byIcon(Icons.gpp_maybe_outlined), findsNothing);
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
        // Deliberately distinct from the static
        // `AppStrings.posterDetailNotFoundTitle`/`...Body` copy, so this
        // test can prove the *backend's* displayMessage is what's shown,
        // not a static string that happens to read similarly. Also proves
        // `POSTER_NOT_FOUND` isn't in `_catalogMessages` — if it ever were
        // added there, this test would start failing and say why.
        error: CatalogException.fromEnvelope(
          backendEnvelopeFixture(
            code: 'POSTER_NOT_FOUND',
            message: 'ไม่พบโปสเตอร์รหัส p1 ในระบบ',
          ),
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
    "this feature's own Thai text for that code (ADR-0017 D9 — network_error "
    "never carries a backend envelope at all, so it always comes from "
    "catalogErrorDisplayMessage's code table, not a displayMessage)",
    (tester) async {
      await tester.pumpWidget(
        wrap(error: const CatalogException(code: 'network_error')),
      );
      await tester.pump();

      expect(find.text('เกิดข้อผิดพลาด'), findsOneWidget);
      expect(find.text(AppStrings.authErrorNetwork), findsOneWidget);
      expect(
        find.text('ไม่สามารถโหลดข้อมูลโปสเตอร์ได้ กรุณาลองใหม่อีกครั้ง'),
        findsNothing,
      );
      expect(find.text('ลองใหม่อีกครั้ง'), findsOneWidget);
    },
  );

  testWidgets(
    "a POSTER_NOT_FOUND-adjacent unmapped code with a backend displayMessage "
    "shows *that* text, proving the envelope path (D2) still works for "
    "codes this feature's table doesn't know about",
    (tester) async {
      await tester.pumpWidget(
        wrap(
          error: CatalogException.fromEnvelope(
            backendEnvelopeFixture(
              code: 'server_maintenance',
              message: 'ระบบปิดปรับปรุงชั่วคราว',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('เกิดข้อผิดพลาด'), findsOneWidget);
      expect(find.text('ระบบปิดปรับปรุงชั่วคราว'), findsOneWidget);
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

  testWidgets(
    'a CatalogException(code: unknown_error) falls back to this screen\'s '
    'own static copy too — same as a non-CatalogException failure, since '
    "unknown_error isn't in this feature's code table and carries no "
    'displayMessage (ADR-0017 D9 — this used to be baked into the exception '
    "at throw time as this exact screen's copy regardless of which screen "
    'rendered it; now every screen resolves its own)',
    (tester) async {
      await tester.pumpWidget(
        wrap(error: const CatalogException(code: 'unknown_error')),
      );
      await tester.pump();

      expect(find.text('เกิดข้อผิดพลาด'), findsOneWidget);
      expect(find.text(AppStrings.posterDetailErrorBody), findsOneWidget);
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

    // Narrowed to the dots' own 6px size (ADR-0012 §D1 7:1067) — a plain
    // `shape == circle` predicate now also matches the Authenticity ring
    // (48px) and the app bar's two glass buttons (40px), both new this
    // round.
    Finder dotFinder() => find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.shape == BoxShape.circle &&
          widget.constraints?.maxWidth == 6;
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

      // ADR-0012 §D1 (7:1067) — the active dot is `AppColors.textPrimary`
      // now, not `AppColors.accent`.
      expect(dotColorAt(tester, 0), AppColors.textPrimary);
      expect(dotColorAt(tester, 1), isNot(AppColors.textPrimary));

      await tester.drag(find.byType(PageView), const Offset(-800, 0));
      await tester.pumpAndSettle();

      expect(dotColorAt(tester, 0), isNot(AppColors.textPrimary));
      expect(dotColorAt(tester, 1), AppColors.textPrimary);
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
        // This alone already proves the label never reached the subtitle —
        // an exact match would fail if it had.
        expect(
          find.text('1941 • ${SizeFormat.oneSheet.label} • Warner Bros'),
          findsOneWidget,
        );
        // A page-wide `textContaining` search stopped being a safe proxy
        // for "not in the subtitle" once ADR-0012 §D4 made the details
        // accordion `initiallyExpanded: true`: §D9 also puts a real
        // release_region UNKNOWN into the accordion *on purpose*
        // (AC-11 — "release_region = UNKNOWN ลงมาเป็นแถวในกล่องพับแทน"),
        // and that row now renders unconditionally instead of needing a
        // tap to expand first, so the same Thai label legitimately shows
        // up there. Assert its (correct) accordion location explicitly
        // instead of a page-wide absence, so the two cases stay
        // distinguishable.
        expect(find.text(ReleaseRegion.unknown.label), findsOneWidget);
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
        wrap(error: const CatalogException(code: 'network_error')),
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
          child: routedApp(
            location: AppRoutes.posterDetail('p1'),
            routes: appRoutes,
          ),
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
          child: routedApp(
            location: AppRoutes.posterDetail('p1'),
            routes: appRoutes,
          ),
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
          child: routedApp(
            location: AppRoutes.posterDetail('p1'),
            routes: appRoutes,
          ),
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

  group('ADR-0012 / AC-12 — figma visual scope', () {
    testWidgets('the gradient background is used, matching every other screen '
        '(§D1 — SCR-05 was the one screen still on a flat ColoredBox)', (
      tester,
    ) async {
      await useTallSurface(tester);
      await tester.pumpWidget(wrap(detail: _fullPoster()));
      await tester.pump();

      expect(find.byType(AppGradientBackground), findsOneWidget);
    });

    testWidgets(
      'the app bar floats transparent over the body rather than sitting in '
      'its own opaque strip (§D1 7:981)',
      (tester) async {
        await useTallSurface(tester);
        await tester.pumpWidget(wrap(detail: _fullPoster()));
        await tester.pump();

        expect(
          tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
          Colors.transparent,
        );
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).extendBodyBehindAppBar,
          isTrue,
        );
      },
    );

    // 🔴 code-critic round 1 (High), mutation 5 + 6b — the first version of
    // this group searched for *literal English* copy lifted straight from
    // the figma frame ('Add to Cart', 'Paper Stock', 'Shipping', 'Returns',
    // 'Certificate of Authenticity', '27"'), but every string this app
    // actually renders comes from `AppStrings` and is 100% Thai — none of
    // those literals can *ever* appear on screen, mutated or not, so the
    // old assertions were unconditionally green (proven: adding real
    // Paper-Stock/Format rows in Thai, and a full heart-button +
    // Add-to-Cart-bar mutation, both left every old assertion passing).
    // `find.byIcon(Icons.favorite/...)` had the same hole one level up —
    // it never covered the `_rounded`/`_sharp`/`_outlined` variant icon
    // families. Rewritten below to assert on *structure* (exact counts of
    // interactive-widget types, an explicit content allowlist) instead of
    // guessing which language or icon a mutation might use.
    testWidgets(
      'the exact set of interactive controls on screen is the audited set '
      '— nothing else may register a tap, regardless of language or icon',
      (tester) async {
        await useTallSurface(tester);
        await tester.pumpWidget(
          wrap(
            detail: _fullPoster(
              images: const [
                PosterImage(
                  id: 'i1',
                  url: 'https://example.invalid/1.jpg',
                  isPrimary: true,
                  sortOrder: 0,
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        // Back + zoom — a wishlist/heart `IconButton` (or any other third
        // one) fails this no matter which icon glyph it uses.
        expect(find.byType(IconButton), findsNWidgets(2));
        // ADR-0005 §D1 — this screen is read-only. No button-shaped widget
        // of any kind exists here at all; an "Add to Cart" control built as
        // any of these fails here regardless of its label's language.
        expect(find.byType(ElevatedButton), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.byType(TextButton), findsNothing);
        // Exactly five things may register a tap here. Two of them are the
        // `IconButton`s already counted above — Material 3's `IconButton`
        // is a `ButtonStyleButton` under the hood, which wraps itself in an
        // `InkWell` too (confirmed against the Flutter 3.44 SDK source; a
        // plain `InkResponse` assumption would have under-counted this).
        // The other three are the zoom hint, the condition-grade badge
        // (opens the scale guide, ADR-0003), and the details accordion's
        // own header (collapse/expand) — `ListTile` always wraps itself in
        // exactly one `InkWell`, which is what `ExpansionTile` uses under
        // the hood for its header row. A sixth would mean a new tappable
        // control slipped in somewhere that isn't an `IconButton`/
        // `*Button` (already ruled out above).
        final tappableInkWells = tester
            .widgetList<InkWell>(find.byType(InkWell))
            .where((w) => w.onTap != null)
            .length;
        expect(tappableInkWells, 5);
        // Every `InkWell` above is itself implemented with an internal
        // `GestureDetector(onTap: handleTap, ...)` (confirmed against the
        // SDK source — `ink_well.dart`'s `_InkResponseState.build()`), so
        // this count tracks the `InkWell` count 1:1 — *unless* something
        // adds a raw `GestureDetector(onTap: ...)` that isn't backed by an
        // `InkWell` at all (a plausible way to build a custom "Add to
        // Cart" control without Material's ripple), which would push this
        // past 5 without moving the `InkWell` count above. The gallery's
        // double-tap-to-zoom `GestureDetector` doesn't count here — it
        // sets `onDoubleTap`, never `onTap`.
        final tappableGestureDetectors = tester
            .widgetList<GestureDetector>(find.byType(GestureDetector))
            .where((w) => w.onTap != null)
            .length;
        expect(tappableGestureDetectors, 5);
        // §D8 — no sticky Add to Cart bar. `bottomNavigationBar` alone
        // isn't enough (a bar built as a `Positioned` inside the body
        // `Stack` instead would slip past it), but the button/tap-surface
        // counts above already account for every interactive element on
        // screen, and `14:59` — the one piece of the bar's copy that isn't
        // free-form Thai prose an allowlist could dodge — still has to
        // literally not exist.
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).bottomNavigationBar,
          isNull,
        );
        expect(find.text('14:59'), findsNothing);
        // §D8 — exactly the one Details accordion; not a second, empty
        // "Shipping & Returns" one.
        expect(find.byType(ExpansionTile), findsOneWidget);
        expect(find.byType(PosterDetailsAccordion), findsOneWidget);
      },
    );

    testWidgets(
      "the details accordion's content is exactly what this fixture's "
      'fields produce — a new row (Paper Stock/Format, in any language) '
      'changes this count, where a literal-text search could not see it',
      (tester) async {
        await useTallSurface(tester);
        await tester.pumpWidget(wrap(detail: _fullPoster()));
        await tester.pump();

        // `_fullPoster()` only ever populates `size`/`provenance`/
        // `description` (`posterType`/`releaseDateText`/`copyrightYear`/
        // `restorationNote` are hardcoded null in this fixture, and
        // `releaseRegion` isn't UNKNOWN here) — so the accordion holds
        // exactly 3 rows: the section title plus 3×(label, value) = 7
        // `Text` nodes total. See `poster_details_accordion_test.dart` for
        // the exhaustive, all-fields-populated version of this same check.
        expect(
          tester.widgetList<Text>(
            find.descendant(
              of: find.byType(PosterDetailsAccordion),
              matching: find.byType(Text),
            ),
          ),
          hasLength(7),
        );
      },
    );

    // 🔴 code-critic round 2, mutations 10a/12 — the round-1 fix covered
    // *tappable controls* and the accordion's *own* content, but nothing
    // else in the body: a COA sentence appended to
    // `PosterAuthenticitySection` and a static-text (no `ExpansionTile`, no
    // tappable widget at all) "Shipping & Returns" block both slipped
    // straight past every round-1 assertion — 121/121 green both times
    // (recorded in skill `project-gotchas`). Neither is a tappable control
    // and neither is inside `PosterDetailsAccordion`, so nothing from
    // round 1 was even looking at them. This closes that gap the same way
    // `poster_details_accordion_test.dart` closed mutation 5: a
    // closed-world content check, just scoped to the rest of the body
    // instead of the accordion.
    testWidgets(
      "the body's text outside the details accordion is exactly what this "
      "fixture's fields produce — a new sentence anywhere else in the body "
      '(COA wording, a static Shipping & Returns block, in any language) '
      'changes this set, where neither a tappable-control count nor the '
      'accordion-only check could see it (code-critic round 2, mutations '
      '10a/12)',
      (tester) async {
        await useTallSurface(tester);
        await tester.pumpWidget(wrap(detail: _fullPoster()));
        await tester.pump();

        // Every `Text` inside `PosterDetailsAccordion` is already covered
        // by the check above (and by `poster_details_accordion_test.dart`
        // exhaustively) — exclude it here so this test owns exactly the
        // complementary scope, not an overlapping one.
        final accordionTexts = find
            .descendant(
              of: find.byType(PosterDetailsAccordion),
              matching: find.byType(Text),
            )
            .evaluate()
            .toSet();
        final outsideAccordionTexts = find
            .descendant(of: find.byType(ListView), matching: find.byType(Text))
            .evaluate()
            .where((element) => !accordionTexts.contains(element))
            .map((element) => (element.widget as Text).data)
            .toSet();

        // Built from `AppStrings` constants and the fixture's own data —
        // never a literal copy-pasted from the design or from what the app
        // happens to render today (the whole point of a closed-world
        // check is that it can't be satisfied by accident).
        const grade = PosterConditionGrade.veryGood;
        expect(outsideAccordionTexts, {
          'Blade Runner', // title — _fullPoster()'s own value
          '1982s • Warner Bros', // subtitle — era_decade + studio fallback
          '฿450.00', // price — formatThbPrice('450.00')
          // ConditionGradeIndicator's own mandated format (ADR-0003).
          '${grade.label} (${grade.scalePosition}/${grade.scaleLength})',
          AppStrings.posterDetailSingleStockNotice,
          // 🔴 ADR-0014 D27 (2026-08-07) — เดิมเซตนี้มีอีก 3 บรรทัด: หัวข้อ
          // 'ความถูกต้องแท้จริง' · ป้าย 'ผ่านการตรวจสอบความแท้แล้ว' · และ
          // `authenticityNote` ของ fixture ('Verified by in-house expert.')
          // ทั้งบล็อกถูกถอดออกจากหน้า จึงหายไปจากเซตนี้ **เพราะเราลบของออกจริง**
          // ไม่ใช่เพราะ assertion อ่อนลง — `_fullPoster()` ยังตั้ง
          // `isAuthenticated: true` + `authenticityNote` ไว้เหมือนเดิม ดังนั้น
          // ถ้ามีใครเอาบล็อกกลับมา เทสนี้จะแดงทันที (นั่นคือหน้าที่ของมัน)
        });
      },
    );

    // 🔴 BL-92 — ช่องที่ `code-critic` ชี้ไว้ตั้งแต่รอบ ADR-0014 D27 แล้วยังไม่ได้ปิด
    // จนถึงวันนี้: closed-world สองตัวข้างบนตรวจ **`Text`** กับ **สิ่งที่กดได้**
    // เท่านั้น · บล็อก "ความถูกต้องแท้จริง" ที่ D27 ถอดออกไปเป็น **วงแหวน 48px +
    // ไอคอนโล่** (ADR-0012 D1 แถว 7:1008) ซึ่งไม่ใช่ทั้งสองอย่าง — เอากลับมาแบบ
    // *ไม่มีข้อความ* และ *กดไม่ได้* แล้วมันลอดครบทุกด่านที่มีอยู่:
    //   · ไม่มี `Text` ใหม่           → เซตข้อความข้างบนไม่ขยับ
    //   · ไม่ใช่ปุ่ม ไม่รับ tap        → จำนวน IconButton/InkWell/GestureDetector ไม่ขยับ
    //   · ไม่ได้อยู่ใน accordion       → เทสของ accordion มองไม่เห็น
    // ที่เหลืออยู่คือ `findsNothing` ของ `gpp_good_outlined`/`gpp_maybe_outlined`
    // สองบรรทัด ซึ่งจับได้เฉพาะตอนที่คนเอา **ไอคอนตัวเดิมเป๊ะ** กลับมา — เปลี่ยนเป็น
    // `Icons.verified` · `Icons.shield_outlined` · `gpp_good` (ไม่มี `_outlined`)
    // ก็ลอดหมด · ปัญหาชนิดเดียวกับที่ comment ของเทสด้านบนบันทึกไว้เองเรื่อง
    // `find.byIcon(Icons.favorite)` ที่ไม่ครอบ `_rounded`/`_sharp`/`_outlined`
    testWidgets('the exact set of icons on screen is the audited set — an authenticity '
        'ring/shield brought back with any glyph, with no text and no tap '
        'handler, fails here where every other closed-world check passes it '
        '(BL-92)', (tester) async {
      await useTallSurface(tester);
      await tester.pumpWidget(
        wrap(
          detail: _fullPoster(
            images: const [
              PosterImage(
                id: 'i1',
                url: 'https://example.invalid/1.jpg',
                isPrimary: true,
                sortOrder: 0,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      // ทั้งหน้า ไม่ใช่แค่ body — วงแหวนความแท้เคยอยู่ใน `ListView` ก็จริง แต่
      // การจำกัด scope ไว้ที่นั่นแปลว่าใครย้ายมันไปแปะบน app bar หรือทับบนรูป
      // (ที่ที่ตราประทับแบบนี้มักไปอยู่) แล้วรอด · ที่นี่จึงนับทุก `Icon` บนจอ
      // และเป็น closed-world ตัวเดียวของไฟล์นี้ที่ครอบ **นอก** `ListView`
      final icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((w) => w.icon)
          .toList();

      // แต่ละตัวมีที่มาที่อ้างได้จากซอร์ส ไม่ใช่จากสิ่งที่จอเรนเดอร์วันนี้ —
      // นั่นคือเงื่อนไขที่ทำให้ allowlist มีค่า (skill `test-quality` §4):
      //   · arrow_back    — `_GlassCircleButton` ของ leading (poster_detail_screen.dart:130)
      //   · zoom_in       — `_ZoomAction` ตอนยังไม่ซูม (:389) · สลับเป็น zoom_out เมื่อซูม
      //   · info_outline  — `ConditionGradeIndicator` ตัวเปิดคู่มือสเกล
      //                     (condition_grade_indicator.dart:110-111 · ADR-0003)
      //   · warning_amber_rounded — ป้ายเร่งเร้าของสถานะ `available`
      //                     (poster_availability_status.dart:68 · ADR-0012 D1 · figma 7:1002)
      //                     · fixture นี้เป็น `PosterStatus.available` จึงต้องมีตัวนี้
      //   · expand_more   — trailing ที่ `ExpansionTile` ใส่ให้เองใน `PosterDetailsAccordion`
      // 🔴 ไม่มีไอคอน "ความแท้" อยู่ในรายการนี้ และนั่นคือทั้งหมดของข้อนี้
      //
      // `unorderedEquals` ไม่ใช่การผ่อน — มันยังบังคับ **จำนวนเท่ากันและจับคู่ได้
      // ครบทุกตัว** (multiset) ของใหม่ตัวเดียวก็แดง · ที่ไม่ล็อกลำดับเพราะลำดับที่ได้
      // คือลำดับ traversal ของ element tree (body มาก่อน app bar) ซึ่งเป็นรายละเอียด
      // ภายในของ `Scaffold` ไม่ใช่กฎที่ ADR ข้อไหนพูดถึง — ล็อกไว้ก็จะแดงจากการ
      // จัดวางใหม่ที่ไม่ได้ผิดอะไร แล้วคนจะแก้ด้วยการเรียงลำดับใน expect ตามไปเรื่อย ๆ
      expect(
        icons,
        unorderedEquals(<IconData>[
          Icons.arrow_back,
          Icons.zoom_in,
          Icons.info_outline,
          Icons.warning_amber_rounded,
          Icons.expand_more,
        ]),
      );

      // ยังเก็บ assertion เชิงลบแบบระบุชื่อไว้ด้วย — ซ้อนกันโดยตั้งใจ ไม่ใช่
      // ของค้าง: ถ้าวันหน้ามีคนขยาย allowlist ข้างบนเพราะเพิ่มไอคอนอื่นเข้ามาจริง
      // (badge บูรณะ · แถบสถานะ) สองบรรทัดนี้ยังกันไอคอนโล่คู่เดิมไว้อยู่
      expect(find.byIcon(Icons.gpp_good_outlined), findsNothing);
      expect(find.byIcon(Icons.gpp_maybe_outlined), findsNothing);
    });
  });
}
