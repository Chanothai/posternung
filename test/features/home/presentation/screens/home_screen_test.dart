import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/catalog/poster_condition_grade.dart';
import 'package:posternung/core/error/catalog_exception.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/home/presentation/screens/home_screen.dart';
import 'package:posternung/features/home/presentation/widgets/home_top_bar.dart';
import 'package:posternung/features/poster/domain/entities/paginated_posters.dart';
import 'package:posternung/features/poster/domain/entities/poster_status.dart';
import 'package:posternung/features/poster/domain/entities/poster_summary.dart';
import 'package:posternung/features/poster/domain/repositories/poster_repository.dart';
import 'package:posternung/features/poster/presentation/providers/poster_providers.dart';
import 'package:posternung/features/poster/presentation/screens/poster_detail_screen.dart';

class FakeAuthViewModel extends AuthViewModel {
  bool signOutCalled = false;

  @override
  FutureOr<void> build() {}

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

class MockPosterRepository extends Mock implements PosterRepository {}

PosterSummary _summary({
  String id = '11111111-1111-4111-8111-111111111111',
  String title = 'Blade Runner',
  String price = '450.00',
  PosterStatus? status = PosterStatus.available,
  PosterConditionGrade? grade = PosterConditionGrade.veryGood,
  int? eraDecade = 1980,
  String? studio = 'Warner Bros',
  String? imageUrl,
}) => PosterSummary(
  id: id,
  title: title,
  price: price,
  status: status,
  conditionGrade: grade,
  eraDecade: eraDecade,
  studio: studio,
  primaryImageUrl: imageUrl,
);

PaginatedPosters _page(List<PosterSummary> items, {int? total}) =>
    PaginatedPosters(
      items: items,
      total: total ?? items.length,
      limit: 20,
      offset: 0,
    );

void main() {
  late FakeAuthViewModel authViewModel;
  late MockPosterRepository repository;

  setUp(() {
    authViewModel = FakeAuthViewModel();
    repository = MockPosterRepository();
  });

  void stubList(PaginatedPosters page) {
    when(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => page);
  }

  /// Slices [catalog] the way the backend does, but never hands back more
  /// than [pageSize] rows per request — so a paging test needs four cards
  /// rather than forty and still lays out on a test surface.
  void stubCatalog(List<PosterSummary> catalog, {int pageSize = 2}) {
    when(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((invocation) async {
      final limit = invocation.namedArguments[#limit] as int;
      final offset = invocation.namedArguments[#offset] as int;
      return PaginatedPosters(
        items: catalog
            .skip(offset)
            .take(limit < pageSize ? limit : pageSize)
            .toList(),
        total: catalog.length,
        limit: limit,
        offset: offset,
      );
    });
  }

  List<PosterSummary> catalogOf(int count) => List.generate(
    count,
    (i) => _summary(id: 'poster-$i', title: 'Poster $i'),
  );

  void stubListError([
    Object error = const CatalogException(
      code: 'server_error',
      message: 'เซิร์ฟเวอร์ขัดข้อง',
    ),
  ]) {
    when(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenThrow(error);
  }

  Widget wrap() => ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith(() => authViewModel),
      // The whole real chain above the repository runs — usecase, provider,
      // widgets — with only the network boundary faked. No real Dio anywhere.
      posterRepositoryProvider.overrideWithValue(repository),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );

  // The grid is a lazy CustomScrollView, so below-the-fold content isn't laid
  // out at the default 800x600 surface. Tests that assert on card content
  // grow the surface first.
  Future<void> useTallSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group('required state: loading', () {
    testWidgets('shows a spinner while the first page is in flight', (
      tester,
    ) async {
      final completer = Completer<PaginatedPosters>();
      when(
        () => repository.listPosters(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(_page([_summary()]));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('required state: empty', () {
    testWidgets('total == 0 shows a readable empty message, not a blank grid', (
      tester,
    ) async {
      await useTallSurface(tester);
      stubList(_page(const [], total: 0));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('ยังไม่มีโปสเตอร์ให้ชมตอนนี้'), findsOneWidget);
      expect(
        find.text(
          'เรากำลังคัดโปสเตอร์ต้นฉบับชิ้นใหม่เข้าร้าน กลับมาดูอีกครั้งเร็ว ๆ นี้',
        ),
        findsOneWidget,
      );
      // Nothing to page through when the catalog itself is empty.
      expect(find.textContaining('แสดง'), findsNothing);
    });
  });

  group('required state: error', () {
    testWidgets('shows the backend message and a working retry button', (
      tester,
    ) async {
      await useTallSurface(tester);
      stubListError();

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('โหลดรายการโปสเตอร์ไม่สำเร็จ'), findsOneWidget);
      expect(find.text('เซิร์ฟเวอร์ขัดข้อง'), findsOneWidget);

      stubList(_page([_summary(title: 'Alien')]));
      await tester.tap(find.text('ลองใหม่อีกครั้ง'));
      await tester.pumpAndSettle();

      expect(find.text('Alien'), findsOneWidget);
      expect(find.text('โหลดรายการโปสเตอร์ไม่สำเร็จ'), findsNothing);
    });

    testWidgets('tapping retry gives immediate visible feedback — a spinner, '
        'not a screen that looks like the tap did nothing', (tester) async {
      await useTallSurface(tester);
      stubListError();

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final completer = Completer<PaginatedPosters>();
      when(
        () => repository.listPosters(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) => completer.future);

      await tester.tap(find.text('ลองใหม่อีกครั้ง'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('ลองใหม่อีกครั้ง'), findsNothing);

      completer.complete(_page([_summary(title: 'Alien')]));
      await tester.pumpAndSettle();
      expect(find.text('Alien'), findsOneWidget);
    });

    testWidgets('a non-CatalogException error still renders the error state '
        'with fallback copy', (tester) async {
      await useTallSurface(tester);
      stubListError(StateError('boom'));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('โหลดรายการโปสเตอร์ไม่สำเร็จ'), findsOneWidget);
      expect(
        find.text('กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ตแล้วลองใหม่อีกครั้ง'),
        findsOneWidget,
      );
    });
  });

  group('required state: sold_out (AC-4)', () {
    testWidgets('sold and reserved posters are labelled unavailable; an '
        'available one is not', (tester) async {
      await useTallSurface(tester);
      stubList(
        _page([
          _summary(id: 'a', title: 'Available One'),
          _summary(id: 'b', title: 'Sold One', status: PosterStatus.sold),
          _summary(
            id: 'c',
            title: 'Reserved One',
            status: PosterStatus.reserved,
          ),
        ]),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('ขายแล้ว'), findsOneWidget);
      expect(find.text('ไม่พร้อมขาย'), findsOneWidget);
      // All three stay in the grid — the list isn't filtered client-side.
      expect(find.text('Available One'), findsOneWidget);
      expect(find.text('Sold One'), findsOneWidget);
      expect(find.text('Reserved One'), findsOneWidget);
    });

    testWidgets('a status this client does not recognize is treated as '
        'unavailable, never as buyable', (tester) async {
      await useTallSurface(tester);
      stubList(_page([_summary(title: 'Unknown Status', status: null)]));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('ไม่พร้อมขาย'), findsOneWidget);
    });

    testWidgets('an unavailable card is still tappable — the detail screen '
        'explains what happened (ADR-0005 §D5)', (tester) async {
      await useTallSurface(tester);
      stubList(
        _page([
          _summary(
            id: '22222222-2222-4222-8222-222222222222',
            title: 'Sold One',
            status: PosterStatus.sold,
          ),
        ]),
      );
      when(() => repository.getPosterDetail(any())).thenThrow(
        const CatalogException(code: 'network_error', message: 'เน็ตหลุด'),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sold One'));
      await tester.pumpAndSettle();

      expect(find.byType(PosterDetailScreen), findsOneWidget);
    });
  });

  group('AC-3 — condition grade never appears as a bare label (ADR-0003)', () {
    testWidgets('every card shows the grade with its position on the scale', (
      tester,
    ) async {
      await useTallSurface(tester);
      stubList(
        _page([
          _summary(id: 'a', title: 'A', grade: PosterConditionGrade.veryGood),
          _summary(id: 'b', title: 'B', grade: PosterConditionGrade.fine),
        ]),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Very Good (5/8)'), findsOneWidget);
      expect(find.text('Fine (4/8)'), findsOneWidget);
      // The regression this guards: "Fine" reads as worse than "Very Good"
      // to a non-collector, when it is in fact better. A bare label anywhere
      // on this screen is the bug.
      for (final grade in PosterConditionGrade.values) {
        expect(
          find.text(grade.label),
          findsNothing,
          reason:
              'bare "${grade.label}" rendered with no scale position — '
              'ADR-0003 forbids it',
        );
      }
    });

    testWidgets('a poster with no grade shows "unspecified" rather than a '
        'price with nothing beside it (BR-05)', (tester) async {
      await useTallSurface(tester);
      stubList(_page([_summary(grade: null)]));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('฿450.00'), findsOneWidget);
      expect(find.text('ไม่ระบุสภาพ'), findsOneWidget);
    });

    testWidgets('tapping the grade badge opens the shared scale guide', (
      tester,
    ) async {
      await useTallSurface(tester);
      stubList(_page([_summary()]));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Very Good (5/8)'));
      await tester.pumpAndSettle();

      expect(find.text('คู่มือระดับสภาพสินค้า'), findsOneWidget);
    });
  });

  group('AC-2 — price presentation and ordering (BR-05)', () {
    testWidgets('prices render in Thai Baht next to their condition', (
      tester,
    ) async {
      await useTallSurface(tester);
      stubList(_page([_summary(price: '1250.50')]));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('฿1,250.50'), findsOneWidget);
    });

    testWidgets('the server ordering is preserved — the grid is never '
        're-sorted cheapest-first on the client', (tester) async {
      await useTallSurface(tester);
      stubList(
        _page([
          _summary(id: 'a', title: 'Expensive', price: '900.00'),
          _summary(id: 'b', title: 'Cheap', price: '100.00'),
          _summary(id: 'c', title: 'Middle', price: '500.00'),
        ]),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final expensive = tester.getTopLeft(find.text('Expensive'));
      final cheap = tester.getTopLeft(find.text('Cheap'));
      final middle = tester.getTopLeft(find.text('Middle'));

      // Row 0: Expensive (left) then Cheap (right). Row 1: Middle.
      expect(expensive.dy, equals(cheap.dy));
      expect(expensive.dx, lessThan(cheap.dx));
      expect(middle.dy, greaterThan(expensive.dy));
    });
  });

  group('card content and navigation', () {
    testWidgets('the subtitle is era decade + studio — never a film year or '
        'size, which GET /posters does not return', (tester) async {
      await useTallSurface(tester);
      stubList(_page([_summary(eraDecade: 1980, studio: 'Warner Bros')]));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('1980s • Warner Bros'), findsOneWidget);
    });

    testWidgets('a poster with neither era nor studio simply has no subtitle', (
      tester,
    ) async {
      await useTallSurface(tester);
      stubList(_page([_summary(eraDecade: null, studio: null)]));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Blade Runner'), findsOneWidget);
      expect(find.textContaining('•'), findsNothing);
    });

    testWidgets('a null primary_image_url renders the placeholder rather than '
        'a broken frame', (tester) async {
      await useTallSurface(tester);
      stubList(_page([_summary(imageUrl: null)]));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.text('Blade Runner'), findsOneWidget);
    });

    testWidgets('tapping a card opens the detail screen with the real backend '
        'uuid, not a synthesized id', (tester) async {
      await useTallSurface(tester);
      const uuid = '33333333-3333-4333-8333-333333333333';
      stubList(_page([_summary(id: uuid, title: 'Blade Runner')]));
      when(() => repository.getPosterDetail(any())).thenThrow(
        const CatalogException(code: 'network_error', message: 'เน็ตหลุด'),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blade Runner'));
      await tester.pumpAndSettle();

      expect(find.byType(PosterDetailScreen), findsOneWidget);
      verify(() => repository.getPosterDetail(uuid)).called(1);
    });
  });

  group('load more (pagination)', () {
    testWidgets('a catalog bigger than what is loaded says how much is shown '
        'and pages the rest in', (tester) async {
      await useTallSurface(tester);
      stubCatalog(catalogOf(4));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('แสดง 2 จาก 4 รายการ'), findsOneWidget);
      expect(find.text('Poster 2'), findsNothing);

      await tester.tap(find.text(AppStrings.homeLoadMoreButton));
      await tester.pumpAndSettle();

      // The first page is still there — this appends, it does not replace.
      expect(find.text('Poster 0'), findsOneWidget);
      expect(find.text('Poster 2'), findsOneWidget);
      expect(find.text('Poster 3'), findsOneWidget);
      verify(() => repository.listPosters(limit: 20, offset: 2)).called(1);
    });

    testWidgets('the pager disappears once the whole catalog is loaded — no '
        'button that would fetch an empty page', (tester) async {
      await useTallSurface(tester);
      stubCatalog(catalogOf(4));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.homeLoadMoreButton));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.homeLoadMoreButton), findsNothing);
      expect(find.textContaining('แสดง'), findsNothing);
    });

    testWidgets('a catalog that fits in one page never shows a pager at all', (
      tester,
    ) async {
      await useTallSurface(tester);
      stubList(_page([_summary()]));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.textContaining('แสดง'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('while the next page is in flight the button says so and the '
        'grid stays on screen', (tester) async {
      await useTallSurface(tester);
      stubCatalog(catalogOf(4));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final completer = Completer<PaginatedPosters>();
      when(
        () => repository.listPosters(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) => completer.future);

      await tester.tap(find.text(AppStrings.homeLoadMoreButton));
      await tester.pump();

      expect(find.text(AppStrings.homeLoadMoreLoading), findsOneWidget);
      // The grid the user is reading must not be swapped for a spinner.
      expect(find.text('Poster 0'), findsOneWidget);
      // Disabled, so the button cannot be hammered into a queue.
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);

      completer.complete(
        PaginatedPosters(items: const [], total: 4, limit: 20, offset: 2),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('a failed page reports itself under the grid and offers a '
        'retry — it never replaces the posters already on screen', (
      tester,
    ) async {
      await useTallSurface(tester);
      stubCatalog(catalogOf(4));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      stubListError(
        const CatalogException(
          code: 'network_error',
          message: 'โหลดหน้าถัดไปไม่ได้',
        ),
      );
      await tester.tap(find.text(AppStrings.homeLoadMoreButton));
      await tester.pumpAndSettle();

      expect(find.text('โหลดหน้าถัดไปไม่ได้'), findsOneWidget);
      expect(find.text('Poster 0'), findsOneWidget);
      // The screen-level error state belongs to a *first* page that failed;
      // an optional extra page must never escalate to it.
      expect(find.text('โหลดรายการโปสเตอร์ไม่สำเร็จ'), findsNothing);

      stubCatalog(catalogOf(4));
      await tester.tap(find.text(AppStrings.homePostersRetryCta));
      await tester.pumpAndSettle();

      expect(find.text('Poster 3'), findsOneWidget);
      expect(find.text('โหลดหน้าถัดไปไม่ได้'), findsNothing);
    });
  });

  group('when Home talks to the backend', () {
    testWidgets('coming back from the background does not re-fetch — the '
        'catalog is read on demand, not on every foreground switch', (
      tester,
    ) async {
      await useTallSurface(tester);
      stubCatalog(catalogOf(4));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      clearInteractions(repository);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      verifyNever(
        () => repository.listPosters(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      );
    });

    testWidgets('pull-to-refresh does re-fetch — it is the user-triggered '
        'path that replaced the app-resume one', (tester) async {
      await useTallSurface(tester);
      stubCatalog(catalogOf(4));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      clearInteractions(repository);

      // Same pattern (and same 900px) as `poster_detail_screen_test.dart`'s
      // pull-to-refresh test: `RefreshIndicator` only arms once the drag
      // covers ~25% of the viewport, which is ~600px on the 2400px test
      // surface, and `pumpAndSettle()` doesn't reliably resolve all three of
      // the indicator's animation phases.
      await tester.fling(find.text('Poster 0'), const Offset(0, 900), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      verify(() => repository.listPosters(limit: 20, offset: 0)).called(1);
    });
  });

  group('surrounding chrome (unchanged by SCR-03)', () {
    testWidgets('renders the brand title and the catalog section heading', (
      tester,
    ) async {
      await useTallSurface(tester);
      stubList(_page([_summary()]));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // The brand title is matched inside the top bar rather than by a bare
      // `find.text`: Home's copy is Thai now and `homeBrandTitle` currently
      // reads the same as the "หน้าหลัก" nav tab, so a global text finder
      // would match two widgets and fail for a reason that has nothing to
      // do with the top bar rendering.
      expect(
        find.descendant(
          of: find.byType(HomeTopBar),
          matching: find.text(AppStrings.homeBrandTitle),
        ),
        findsOneWidget,
      );
      expect(find.text('โปสเตอร์ทั้งหมด'), findsOneWidget);
      // Cut this round — no curation table, no expiry field behind them.
      expect(find.text('Featured Collections'), findsNothing);
      expect(find.text('Ending Soon'), findsNothing);
    });

    testWidgets('tapping a not-yet-built nav tab shows the coming-soon '
        'snackbar', (tester) async {
      stubList(_page([_summary()]));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('ค้นหา'));
      await tester.pump();

      expect(find.text('ฟีเจอร์นี้กำลังจะมาเร็ว ๆ นี้'), findsOneWidget);
    });

    testWidgets('the wishlist heart is still coming-soon (US-04 is outside '
        'Phase 1)', (tester) async {
      await useTallSurface(tester);
      stubList(_page([_summary()]));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('เพิ่มลงรายการที่อยากได้'));
      await tester.pump();

      expect(find.text('ฟีเจอร์นี้กำลังจะมาเร็ว ๆ นี้'), findsOneWidget);
    });

    testWidgets('tapping Profile signs out', (tester) async {
      stubList(_page([_summary()]));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('โปรไฟล์'));
      await tester.pump();

      expect(authViewModel.signOutCalled, isTrue);
    });

    testWidgets('top bar collapses continuously on scroll down and recovers '
        'on scroll up', (tester) async {
      // Deliberately the *default* 800x600 surface: the grid has to overflow
      // the viewport for there to be anything to scroll, and a tall test
      // surface would fit all 8 cards and make the drag a no-op.
      stubList(
        _page(List.generate(8, (i) => _summary(id: 'p$i', title: 'Poster $i'))),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // SliverPersistentHeader(floating: true) is backed by more than one
      // RenderSliverPersistentHeader (an inner wrapper); the live one carries
      // the actual paint extent, so read the max across them.
      double paintExtent() => tester.allRenderObjects
          .whereType<RenderSliverPersistentHeader>()
          .map((h) => h.geometry?.paintExtent ?? 0.0)
          .reduce(math.max);

      final fullExtent = paintExtent();
      expect(fullExtent, greaterThan(0));

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pump();
      final collapsedExtent = paintExtent();
      expect(collapsedExtent, lessThan(fullExtent));

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
      await tester.pump();
      expect(paintExtent(), greaterThan(collapsedExtent));
    });
  });
}
