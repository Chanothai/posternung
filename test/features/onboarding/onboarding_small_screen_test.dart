import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/onboarding/presentation/screens/onboarding_page_view_screen.dart';
import 'package:posternung/features/onboarding/presentation/widgets/onboarding_authenticate_page_content.dart';
import 'package:posternung/features/onboarding/presentation/widgets/onboarding_first_page_content.dart';
import 'package:posternung/features/onboarding/presentation/widgets/onboarding_footer.dart';
import 'package:posternung/features/onboarding/presentation/widgets/onboarding_header.dart';
import 'package:posternung/features/onboarding/presentation/widgets/onboarding_limit_stock_page_content.dart';

import '../../support/router_harness.dart';

/// Onboarding on screens the rest of the suite never renders.
///
/// The rest of `test/features/onboarding/` was green while onboarding
/// overflowed on real phones, because `flutter test`'s default surface is
/// 800×600 — wider than every phone the app claims to support. That gap *is*
/// SCR-01's second `known_gap`, so this file's whole job is to render the
/// screen at widths that can actually fail.
///
/// **Two kinds of assertion, because there are two kinds of failure.**
/// `takeException()` sees a `RenderFlex` whose children do not fit — and sees
/// nothing at all when a text run is painted past the edge of its own
/// paragraph box, which is silent. So geometry is measured directly as well.
///
/// **What this file cannot prove.** `google_fonts` fetches Kanit at runtime
/// and `pubspec.yaml` declares no `fonts:` block, so there is no Kanit here:
/// the test font advances every glyph by roughly the font size, while real
/// Thai Kanit glyphs are around half that. Measured widths are therefore an
/// *upper bound*, not the device's numbers (ADR-0023 §Consequences 6,
/// `test-quality` §5). That cuts one way only, and it is the useful way —
/// "nothing overflows even with glyphs this wide" still holds once the
/// glyphs get narrower. The reverse claim, "it overflows by N pixels on a
/// phone", this file must not be used to make; that needs
/// `run-and-verify-on-device` at a real 320 dp.
void main() {
  // ADR-0023 D5. 320 dp is the declared floor (iPhone SE 1st gen; Android at
  // its largest display size) and must not overflow. 360 dp is the common
  // Android width the registry recorded a number for. 280×480 is below the
  // floor and is held to the weaker bar D5 sets for it.
  const Size supportedFloor = Size(320, 568);
  const Size commonAndroid = Size(360, 640);
  const Size belowFloor = Size(280, 480);

  // The second axis of D5.
  const List<double> textScales = <double>[1.0, 1.5];

  for (final Size size in <Size>[supportedFloor, commonAndroid]) {
    for (final double scale in textScales) {
      testWidgets(
        'nothing on any onboarding page is painted outside its box at '
        '${size.width.toInt()} dp with text scale $scale',
        (WidgetTester tester) async {
          await _pumpOnboarding(tester, size: size, textScale: scale);

          for (int page = 0; page < 3; page++) {
            if (page > 0) await _tapNext(tester);

            expect(
              _overflowsIn(tester),
              isEmpty,
              reason:
                  'page ${page + 1} at ${size.width.toInt()} dp × $scale — a '
                  'box or a text run is painted outside its parent',
            );
            expect(
              _outsideScreen(tester, page: page, screenWidth: size.width),
              isEmpty,
              reason:
                  'page ${page + 1} at ${size.width.toInt()} dp × $scale — '
                  'content reaches past the left or right edge of the screen',
            );
            expect(
              tester.takeException(),
              isNull,
              reason: 'page ${page + 1} at ${size.width.toInt()} dp × $scale',
            );
          }
        },
      );
    }
  }

  for (final double scale in textScales) {
    testWidgets('below the supported floor (${belowFloor.width.toInt()}×'
        '${belowFloor.height.toInt()}, text scale $scale) onboarding still '
        'renders without error and every page scrolls (ADR-0023 D5)', (
      WidgetTester tester,
    ) async {
      await _pumpOnboarding(tester, size: belowFloor, textScale: scale);

      for (int page = 0; page < 3; page++) {
        if (page > 0) await _tapNext(tester);

        // D5 asks for "does not error and can be scrolled" here, not for
        // pixel-perfect layout — so this is the whole bar, deliberately.
        expect(
          _scrollExtentOfCurrentPage(tester, page: page),
          greaterThan(0),
          reason:
              'page ${page + 1} does not scroll, so the content that does '
              'not fit is unreachable rather than merely cramped',
        );
        expect(
          tester.takeException(),
          isNull,
          reason:
              'page ${page + 1} at ${belowFloor.width.toInt()} dp × '
              '$scale',
        );
      }
    });
  }
}

final List<Finder> _pageContents = <Finder>[
  find.byType(OnboardingFirstPageContent),
  find.byType(OnboardingAuthenticatePageContent),
  find.byType(OnboardingLimitStockPageContent),
];

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  required Size size,
  required double textScale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Set on the platform dispatcher rather than through a `MediaQuery` the
  // test inserts, so the value travels the same path an OS font-size setting
  // does — `MaterialApp` builds its own `MediaQuery` from the view and would
  // discard an ancestor one.
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    ProviderScope(
      child: routedApp(routes: routesHosting(const OnboardingPageViewScreen())),
    ),
  );
  await tester.pumpAndSettle();

  // Harness guard, not an assertion about the app: if the text scale never
  // reached the widget tree, half the cases below would silently be duplicates
  // of the other half.
  expect(
    MediaQuery.textScalerOf(
      tester.element(find.byType(OnboardingPageViewScreen)),
    ).scale(10),
    10 * textScale,
    reason: 'the text scale under test never reached the screen',
  );
}

/// Advances by tapping the real CTA, so the screen's own paging code runs.
Future<void> _tapNext(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.onboardingNextButton));
  await tester.pumpAndSettle();
}

/// Every `Row`/`Column` whose children paint past its own box, and every
/// paragraph whose longest laid-out line is wider than the box it was given.
///
/// Measured rather than caught: `RenderFlex` reports an overflow only once per
/// layout, so chrome shared across pages (the header, the CTA) goes quiet on
/// the second page while still overflowing — and a text run that does not fit
/// never raises anything at all.
List<String> _overflowsIn(WidgetTester tester) {
  final List<String> out = <String>[];

  void visit(Element e) {
    // Only elements that *own* a render object: `Element.renderObject` walks
    // down to the nearest descendant one, so every ancestor would otherwise
    // report the same box over and over.
    final RenderObject? ro = e is RenderObjectElement ? e.renderObject : null;
    if (ro is RenderFlex && ro.hasSize) {
      Rect? kids;
      ro.visitChildren((RenderObject child) {
        if (child is RenderBox && child.hasSize) {
          final BoxParentData pd = child.parentData! as BoxParentData;
          final Rect r = pd.offset & child.size;
          kids = kids == null ? r : kids!.expandToInclude(r);
        }
      });
      if (kids != null) {
        if (kids!.right - ro.size.width > 0.5) {
          out.add(
            'flex overflows horizontally by '
            '${(kids!.right - ro.size.width).toStringAsFixed(1)} at '
            '${e.debugGetCreatorChain(4)}',
          );
        }
        if (kids!.bottom - ro.size.height > 0.5) {
          out.add(
            'flex overflows vertically by '
            '${(kids!.bottom - ro.size.height).toStringAsFixed(1)} at '
            '${e.debugGetCreatorChain(4)}',
          );
        }
      }
    }
    if (ro is RenderParagraph && ro.hasSize) {
      final TextPainter tp = TextPainter(
        text: ro.text,
        textDirection: ro.textDirection,
        textAlign: ro.textAlign,
        textScaler: ro.textScaler,
        maxLines: ro.maxLines,
        locale: ro.locale,
        strutStyle: ro.strutStyle,
        textWidthBasis: ro.textWidthBasis,
        // `softWrap` and `ellipsis` have to be carried over or this
        // re-layout would wrap text the real paragraph does not wrap, and
        // ellipsize nothing where the real one ellipsizes — either way
        // measuring a paragraph that is not the one on screen.
        ellipsis: ro.overflow == TextOverflow.ellipsis ? '…' : null,
      )..layout(maxWidth: ro.softWrap ? ro.size.width : double.infinity);
      double widest = 0;
      for (final LineMetrics m in tp.computeLineMetrics()) {
        if (m.width > widest) widest = m.width;
      }
      tp.dispose();
      if (widest - ro.size.width > 0.5) {
        out.add(
          'text run overflows its box by '
          '${(widest - ro.size.width).toStringAsFixed(1)}: '
          '"${ro.text.toPlainText().replaceAll('\n', ' / ')}"',
        );
      }
    }
    e.visitChildren(visit);
  }

  visit(tester.element(find.byType(OnboardingPageViewScreen)));
  return out;
}

/// Anything in the *visible* chrome or page content that reaches past the
/// screen's left or right edge.
///
/// Scoped to the header, the footer and the page currently on screen: a
/// `PageView` keeps its neighbours built and parked one screen width away, and
/// they are supposed to be off the edge.
List<String> _outsideScreen(
  WidgetTester tester, {
  required int page,
  required double screenWidth,
}) {
  final List<String> out = <String>[];

  final Map<String, Finder> subtrees = <String, Finder>{
    'the header': find.byType(OnboardingHeader),
    'the footer': find.byType(OnboardingFooter),
    'page ${page + 1}': _pageContents[page],
  };

  for (final MapEntry<String, Finder> entry in subtrees.entries) {
    Rect? bounds;
    void visit(Element e) {
      final RenderObject? ro = e is RenderObjectElement ? e.renderObject : null;
      if (ro is RenderBox && ro.hasSize && ro.attached) {
        // Through the full transform, not `localToGlobal` + `size`: page 3
        // rotates its poster cards and the CTA label is scaled by a
        // `FittedBox`, and taking the origin alone would report the
        // *untransformed* size at the transformed origin.
        final Rect r = MatrixUtils.transformRect(
          ro.getTransformTo(null),
          Offset.zero & ro.size,
        );
        bounds = bounds == null ? r : bounds!.expandToInclude(r);
      }
      e.visitChildren(visit);
    }

    visit(tester.element(entry.value));
    if (bounds!.left < -0.5 || bounds!.right > screenWidth + 0.5) {
      out.add(
        '${entry.key} spans ${bounds!.left.toStringAsFixed(1)}..'
        '${bounds!.right.toStringAsFixed(1)} on a $screenWidth dp screen',
      );
    }
  }
  return out;
}

double _scrollExtentOfCurrentPage(WidgetTester tester, {required int page}) {
  final Finder scroller = find
      .ancestor(of: _pageContents[page], matching: find.byType(Scrollable))
      .first;
  return tester.state<ScrollableState>(scroller).position.maxScrollExtent;
}
