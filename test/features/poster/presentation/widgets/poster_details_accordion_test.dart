import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/poster_type.dart';
import 'package:posternung/core/catalog/release_region.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/poster/presentation/widgets/poster_details_accordion.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  /// ADR-0012 §D4 made the tile `initiallyExpanded: true`, so its `children`
  /// are already in the tree after the first pump — this used to tap the
  /// tile to open it, which would now toggle it *closed* instead. Kept as a
  /// named no-op (rather than deleted at every call site) so a future
  /// revert of §D4 has one place to restore the tap.
  Future<void> expand(WidgetTester tester) async {
    await tester.pumpAndSettle();
  }

  // Every field populated — the base for the "hide one at a time" tests
  // below, so each test proves that hiding *this* field's row leaves every
  // other row alone.
  const fullPosterType = PosterType.theatrical;
  const fullSize = '27x41 in';
  const fullReleaseDateText = 'SUMMER 2021';
  const fullCopyrightYear = 2021;
  const fullProvenance = 'Estate collection, Los Angeles.';
  const fullRestorationNote = 'Linen-backed and re-margined.';
  const fullDescription = 'US theatrical one-sheet.';

  PosterDetailsAccordion accordion({
    PosterType? posterType = fullPosterType,
    String? size = fullSize,
    String? releaseDateText = fullReleaseDateText,
    int? copyrightYear = fullCopyrightYear,
    String? provenance = fullProvenance,
    String? restorationNote = fullRestorationNote,
    String? description = fullDescription,
    ReleaseRegion? releaseRegion,
  }) => PosterDetailsAccordion(
    posterType: posterType,
    size: size,
    releaseDateText: releaseDateText,
    copyrightYear: copyrightYear,
    provenance: provenance,
    restorationNote: restorationNote,
    description: description,
    releaseRegion: releaseRegion,
  );

  const emptyAccordion = PosterDetailsAccordion(
    posterType: null,
    size: null,
    releaseDateText: null,
    copyrightYear: null,
    provenance: null,
    restorationNote: null,
    description: null,
    releaseRegion: null,
  );

  testWidgets(
    'every field null/absent — the whole accordion is omitted, not an '
    'empty expandable tile',
    (tester) async {
      await tester.pumpWidget(wrap(emptyAccordion));

      expect(find.byType(ExpansionTile), findsNothing);
    },
  );

  testWidgets(
    'a real (non-UNKNOWN) release_region contributes no row of its own — '
    'it lives in the subtitle, not here — so the accordion still hides '
    'when every other field is null',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          accordion(
            posterType: null,
            size: null,
            releaseDateText: null,
            copyrightYear: null,
            provenance: null,
            restorationNote: null,
            description: null,
            releaseRegion: ReleaseRegion.us,
          ),
        ),
      );

      expect(find.byType(ExpansionTile), findsNothing);
    },
  );

  testWidgets(
    'shows every row when every field has data, in the fixed §D1′ order',
    (tester) async {
      await tester.pumpWidget(wrap(accordion()));
      await expand(tester);

      expect(find.text('Theatrical'), findsOneWidget);
      expect(find.text(fullSize), findsOneWidget);
      expect(find.text(fullReleaseDateText), findsOneWidget);
      expect(find.text('$fullCopyrightYear'), findsOneWidget);
      expect(find.text(fullProvenance), findsOneWidget);
      expect(find.text(fullRestorationNote), findsOneWidget);
      expect(find.text(fullDescription), findsOneWidget);
      // No UNKNOWN region row — release_region is null in this fixture.
      expect(find.text('ตรวจแล้วระบุไม่ได้'), findsNothing);
    },
  );

  testWidgets(
    'ADR-0011 §D7/§D9 — release_region shows its own row only when it is '
    'specifically UNKNOWN, distinct from a real region or null',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          const PosterDetailsAccordion(
            posterType: null,
            size: null,
            releaseDateText: null,
            copyrightYear: null,
            provenance: null,
            restorationNote: null,
            description: null,
            releaseRegion: ReleaseRegion.unknown,
          ),
        ),
      );
      await expand(tester);

      expect(find.text('ตรวจแล้วระบุไม่ได้'), findsOneWidget);
    },
  );

  // AC-7 / code-critic round 1 H3 — proves hide-empty is enforced *per
  // row*, not just "the whole box disappears when everything is empty".
  // code-critic found the previous version of this file never actually
  // asserted a null field's row was gone: patching production to render
  // `'-'` for a null `poster_type`/`copyright_year` still passed every
  // test here. Each case below hides exactly one field and checks (a) its
  // own label is gone, (b) no `'-'` placeholder appears anywhere, and (c)
  // every sibling row that still has data is untouched.
  group('AC-7 — a null field hides only its own row, never a "-" '
      'placeholder', () {
    testWidgets('poster_type null', (tester) async {
      await tester.pumpWidget(wrap(accordion(posterType: null)));
      await expand(tester);

      expect(find.text(AppStrings.posterDetailPosterTypeLabel), findsNothing);
      expect(find.text('-'), findsNothing);
      expect(find.text(fullSize), findsOneWidget);
      expect(find.text(fullReleaseDateText), findsOneWidget);
      expect(find.text('$fullCopyrightYear'), findsOneWidget);
      expect(find.text(fullProvenance), findsOneWidget);
      expect(find.text(fullRestorationNote), findsOneWidget);
      expect(find.text(fullDescription), findsOneWidget);
    });

    testWidgets('size null', (tester) async {
      await tester.pumpWidget(wrap(accordion(size: null)));
      await expand(tester);

      expect(find.text(AppStrings.posterDetailSizeLabel), findsNothing);
      expect(find.text('-'), findsNothing);
      expect(find.text('Theatrical'), findsOneWidget);
      expect(find.text(fullReleaseDateText), findsOneWidget);
      expect(find.text('$fullCopyrightYear'), findsOneWidget);
      expect(find.text(fullProvenance), findsOneWidget);
      expect(find.text(fullRestorationNote), findsOneWidget);
      expect(find.text(fullDescription), findsOneWidget);
    });

    testWidgets('release_date_text null', (tester) async {
      await tester.pumpWidget(wrap(accordion(releaseDateText: null)));
      await expand(tester);

      expect(
        find.text(AppStrings.posterDetailReleaseDateTextLabel),
        findsNothing,
      );
      expect(find.text('-'), findsNothing);
      expect(find.text('Theatrical'), findsOneWidget);
      expect(find.text(fullSize), findsOneWidget);
      expect(find.text('$fullCopyrightYear'), findsOneWidget);
      expect(find.text(fullProvenance), findsOneWidget);
      expect(find.text(fullRestorationNote), findsOneWidget);
      expect(find.text(fullDescription), findsOneWidget);
    });

    testWidgets('copyright_year null', (tester) async {
      await tester.pumpWidget(wrap(accordion(copyrightYear: null)));
      await expand(tester);

      expect(
        find.text(AppStrings.posterDetailCopyrightYearLabel),
        findsNothing,
      );
      expect(find.text('-'), findsNothing);
      expect(find.text('Theatrical'), findsOneWidget);
      expect(find.text(fullSize), findsOneWidget);
      expect(find.text(fullReleaseDateText), findsOneWidget);
      expect(find.text(fullProvenance), findsOneWidget);
      expect(find.text(fullRestorationNote), findsOneWidget);
      expect(find.text(fullDescription), findsOneWidget);
    });

    testWidgets('provenance null', (tester) async {
      await tester.pumpWidget(wrap(accordion(provenance: null)));
      await expand(tester);

      expect(find.text(AppStrings.posterDetailProvenanceLabel), findsNothing);
      expect(find.text('-'), findsNothing);
      expect(find.text('Theatrical'), findsOneWidget);
      expect(find.text(fullSize), findsOneWidget);
      expect(find.text(fullReleaseDateText), findsOneWidget);
      expect(find.text('$fullCopyrightYear'), findsOneWidget);
      expect(find.text(fullRestorationNote), findsOneWidget);
      expect(find.text(fullDescription), findsOneWidget);
    });

    testWidgets('restoration_note null', (tester) async {
      await tester.pumpWidget(wrap(accordion(restorationNote: null)));
      await expand(tester);

      expect(
        find.text(AppStrings.posterDetailRestorationNoteLabel),
        findsNothing,
      );
      expect(find.text('-'), findsNothing);
      expect(find.text('Theatrical'), findsOneWidget);
      expect(find.text(fullSize), findsOneWidget);
      expect(find.text(fullReleaseDateText), findsOneWidget);
      expect(find.text('$fullCopyrightYear'), findsOneWidget);
      expect(find.text(fullProvenance), findsOneWidget);
      expect(find.text(fullDescription), findsOneWidget);
    });

    testWidgets('description null', (tester) async {
      await tester.pumpWidget(wrap(accordion(description: null)));
      await expand(tester);

      expect(find.text(AppStrings.posterDetailDescriptionLabel), findsNothing);
      expect(find.text('-'), findsNothing);
      expect(find.text('Theatrical'), findsOneWidget);
      expect(find.text(fullSize), findsOneWidget);
      expect(find.text(fullReleaseDateText), findsOneWidget);
      expect(find.text('$fullCopyrightYear'), findsOneWidget);
      expect(find.text(fullProvenance), findsOneWidget);
      expect(find.text(fullRestorationNote), findsOneWidget);
    });
  });

  // code-critic round 1 M2 — the same trim-to-missing rule that fixed
  // `poster_detail_screen.dart`'s "2010s •" bug (a blank, not null, wire
  // value) applies to every `String?` row here.
  group('M2 — a blank (whitespace-only) String? field is treated as '
      'missing, same as null', () {
    testWidgets('blank size hides its row', (tester) async {
      await tester.pumpWidget(wrap(accordion(size: '   ')));
      await expand(tester);

      expect(find.text(AppStrings.posterDetailSizeLabel), findsNothing);
    });

    testWidgets('blank release_date_text hides its row', (tester) async {
      await tester.pumpWidget(wrap(accordion(releaseDateText: '')));
      await expand(tester);

      expect(
        find.text(AppStrings.posterDetailReleaseDateTextLabel),
        findsNothing,
      );
    });

    testWidgets('blank provenance hides its row', (tester) async {
      await tester.pumpWidget(wrap(accordion(provenance: ' \t')));
      await expand(tester);

      expect(find.text(AppStrings.posterDetailProvenanceLabel), findsNothing);
    });

    testWidgets('blank restoration_note hides its row', (tester) async {
      await tester.pumpWidget(wrap(accordion(restorationNote: '')));
      await expand(tester);

      expect(
        find.text(AppStrings.posterDetailRestorationNoteLabel),
        findsNothing,
      );
    });

    testWidgets('blank description hides its row', (tester) async {
      await tester.pumpWidget(wrap(accordion(description: '   ')));
      await expand(tester);

      expect(find.text(AppStrings.posterDetailDescriptionLabel), findsNothing);
    });

    testWidgets(
      'every String? field blank (and no other field set) — the whole '
      'accordion is omitted, not an empty tile',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const PosterDetailsAccordion(
              posterType: null,
              size: '  ',
              releaseDateText: '',
              copyrightYear: null,
              provenance: ' ',
              restorationNote: '\n',
              description: '',
              releaseRegion: null,
            ),
          ),
        );

        expect(find.byType(ExpansionTile), findsNothing);
      },
    );
  });

  // 🔴 code-critic round 1 (High), mutation 5 — added Paper Stock/Format
  // rows here using real Thai `AppStrings`-style labels, and every
  // `find.textContaining('Paper Stock'/'Format')` assertion in
  // `poster_detail_screen_test.dart` stayed green, because that copy is
  // English and this app's copy never is. A closed-world content check
  // catches an extra row regardless of what language or text it uses.
  testWidgets(
    'with every field populated, the accordion renders exactly the title '
    'plus one (label, value) pair per field — no more, no less, in any '
    'language (code-critic mutation 5)',
    (tester) async {
      await tester.pumpWidget(
        wrap(accordion(releaseRegion: ReleaseRegion.unknown)),
      );
      await expand(tester);

      final texts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(ExpansionTile),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();

      expect(texts.length, 17); // title + 8 fields × (label, value)
      expect(texts.toSet(), {
        AppStrings.posterDetailDetailsSectionTitle,
        AppStrings.posterDetailPosterTypeLabel,
        fullPosterType.label,
        AppStrings.posterDetailSizeLabel,
        fullSize,
        AppStrings.posterDetailReleaseDateTextLabel,
        fullReleaseDateText,
        AppStrings.posterDetailCopyrightYearLabel,
        '$fullCopyrightYear',
        AppStrings.posterDetailProvenanceLabel,
        fullProvenance,
        AppStrings.posterDetailRestorationNoteLabel,
        fullRestorationNote,
        AppStrings.posterDetailDescriptionLabel,
        fullDescription,
        AppStrings.posterDetailReleaseRegionLabel,
        ReleaseRegion.unknown.label,
      });
    },
  );

  // 🔴 code-critic round 1 (Medium) — the bare `Text(label)` in `_inline()`
  // had no width limit, so it could push past the row on a real phone
  // width; `useTallSurface`'s 800px-wide binding everywhere else in this
  // suite never exercises that. A/B proof from code-critic: HEAD (the old
  // label-above-value `Column` layout) overflowed 0/9 width×textScale
  // combinations, the un-`Flexible`d `Row` overflowed 6/9. This pins the
  // fix (`Flexible` around the label) at both a narrow phone width and a
  // large accessibility text scale — the two axes that actually surfaced
  // the class.
  testWidgets(
    'a long label does not overflow its row on a narrow phone width with a '
    'large text scale (code-critic A/B: 6/9 combinations overflowed before '
    '`Flexible`)',
    (tester) async {
      tester.view.physicalSize = const Size(320, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: accordion(
                // The longest real label in the allowlist — the one most
                // likely to actually collide with the value column.
                posterType: fullPosterType,
                size: fullSize,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
