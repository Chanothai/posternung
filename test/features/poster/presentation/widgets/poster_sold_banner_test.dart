import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/core/theme/app_colors.dart';
import 'package:posternung/core/theme/app_theme.dart';
import 'package:posternung/features/poster/presentation/widgets/poster_sold_banner.dart';

void main() {
  // `AppTheme.dark()` on purpose — the subject of this file is what the
  // app's own theme does (or must not do) to this widget, so pumping the
  // `ThemeData()` default would prove nothing (SCR-07 B9 GATE 2 (จ)).
  Widget wrap({VoidCallback? onBrowseOthers}) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: PosterSoldBanner(onBrowseOthers: onBrowseOthers ?? () {}),
    ),
  );

  /// The `Material` an `OutlinedButton` actually paints — `ButtonStyleButton`
  /// resolves its `ButtonStyle` (widget ⊕ theme ⊕ defaults) into this one
  /// widget's `shape`/`color`, so it is the resolved result, not any single
  /// input.
  Material paintedButton(WidgetTester tester) => tester.widget<Material>(
    find
        .descendant(
          of: find.byType(OutlinedButton),
          matching: find.byType(Material),
        )
        .first,
  );

  testWidgets('renders the sold copy and the CTA, and the CTA calls back', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(wrap(onBrowseOthers: () => taps++));

    expect(find.text(AppStrings.posterDetailSoldTitle), findsOneWidget);
    expect(find.text(AppStrings.posterDetailSoldBody), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, AppStrings.posterDetailSoldCta),
      findsOneWidget,
    );

    await tester.tap(find.byType(OutlinedButton));
    expect(taps, 1);
  });

  testWidgets(
    '(จ1) under AppTheme the CTA is still a stadium pill in accentRed with '
    'no fill — the theme must not carry an `outlinedButtonTheme`. 🔴 '
    'mutation-locking: putting the `secondaryButtonFill` / radius-4 '
    '`outlinedButtonTheme` back into `AppTheme.dark()` turns this red',
    (tester) async {
      await tester.pumpWidget(wrap());

      // Belt and braces: the theme entry itself is absent …
      expect(AppTheme.dark().outlinedButtonTheme.style, isNull);

      // … and what is painted is Material's own OutlinedButton default
      // shape plus this widget's side/foreground, nothing from a theme.
      final Material painted = paintedButton(tester);
      expect(painted.shape, isA<StadiumBorder>());
      expect(painted.shape, isNot(isA<RoundedRectangleBorder>()));
      expect((painted.shape! as StadiumBorder).side.color, AppColors.accentRed);
      expect(painted.color, isNot(AppColors.secondaryButtonFill));
      expect(painted.color, Colors.transparent);
    },
  );
}
