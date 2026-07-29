import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/poster_condition_grade.dart';
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
}) => PosterDetail(
  id: 'p1',
  title: 'Blade Runner',
  price: '450.00',
  status: status,
  conditionGrade: conditionGrade,
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

    expect(find.text('Blade Runner'), findsOneWidget);
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
    expect(find.text('Untitled Import'), findsOneWidget);
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
      expect(find.text('Blade Runner'), findsOneWidget);
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
      await tester.fling(find.text('Blade Runner'), const Offset(0, 900), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(viewModel.refreshCalls, 1);
    });
  });
}
