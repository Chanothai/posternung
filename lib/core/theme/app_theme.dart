import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../design_system/app_dimens.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// The one `ThemeData` the app runs on (`main.dart` → `MaterialApp.router`).
///
/// Until SCR-07 B9 the app had **no theme at all** beyond
/// `ColorScheme.fromSeed(seedColor: Colors.deepPurple)` — so every widget
/// had to restate its colours, borders and fonts, and any `Text` or
/// `InputDecoration` that forgot fell back to Roboto + seed-purple on a
/// warm dark ground (the `AppStatusView` incident in `lib/core/CLAUDE.md`,
/// and B8-UI on `/checkout`). This class moves those defaults into one
/// place so a feature only declares what *differs* from the theme.
///
/// Rule of precedence (`lib/core/CLAUDE.md`): a style a widget sets itself
/// always wins over the theme — the theme fills in only what the widget
/// left `null`. The auth cards' white inputs (`fillColor: AppColors.white`)
/// therefore stay white under the dark `inputDecorationTheme` below.
///
/// Values are the Figma 7:1201 reference mapped onto existing tokens; where
/// a Figma number has no token (input padding 17/14 → 16/12) the nearest
/// `AppSpacing` step is used, never a literal — the deltas are recorded in
/// the SCR-07 B9 gate report, not here.
abstract final class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final ColorScheme colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.accent,
          onPrimary: AppColors.white,
          surface: AppColors.surfaceDark,
          onSurface: AppColors.textPrimary,
          error: AppColors.accentRed,
        );

    // Kanit for every slot of the Material text theme, all in `textPrimary`
    // — the safety net for a `Text` that names no `AppTextStyles` entry.
    final TextTheme textTheme =
        GoogleFonts.kanitTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ).apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );

    // 🔴 Every state border is set explicitly. Setting only `border:` is not
    // enough under Material 3: `InputDecorator._getDefaultBorder` swaps the
    // side for the theme's `activeIndicatorBorder`, so a `border:`-only
    // decoration never paints the colour it names (SCR-02 gap N-1).
    OutlineInputBorder inputOutline(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      borderSide: BorderSide(color: color),
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surfaceDark,
      textTheme: textTheme,
      appBarTheme: AppBarThemeData(
        // Transparent so a screen's own backdrop (image, gradient, blur)
        // shows through — SCR-05's header already did this per call site.
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: AppTextStyles.appBarTitle,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.inputFill,
        enabledBorder: inputOutline(AppColors.inputBorder),
        focusedBorder: inputOutline(AppColors.accent),
        disabledBorder: inputOutline(AppColors.inputBorder),
        errorBorder: inputOutline(AppColors.accentRed),
        focusedErrorBorder: inputOutline(AppColors.accentRed),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTextStyles.inputTextOnDark.copyWith(
          color: AppColors.placeholderGray,
        ),
        labelStyle: AppTextStyles.formLabel,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          shape: const StadiumBorder(),
          textStyle: AppTextStyles.ctaLabel,
          // Figma's CTA shadow (offset 2,3 · blur 5 · `ctaShadow`) has no
          // exact Material equivalent — elevation 1 with the same tint is
          // the closest an `ElevatedButton` can get without a custom
          // painter, and the surface tint is switched off so Material 3
          // does not wash the accent with `colorScheme.surfaceTint`.
          elevation: 1,
          shadowColor: AppColors.ctaShadow,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      // 🔴 Deliberately no `outlinedButtonTheme` (SCR-07 B9 GATE 2 (จ1)):
      // a `secondaryButtonFill` / radius-4 entry here restyled every
      // `OutlinedButton` outside checkout (`AppStatusView` CTA ·
      // `home_load_more_footer` · `poster_sold_banner`'s pill · profile
      // sign-out · login Google) while checkout itself has no secondary
      // button yet. The tokens (`AppColors.secondaryButtonFill`,
      // `AppTextStyles.secondaryButtonLabel`) stay for BL-154, which
      // re-introduces the entry screen by screen. `test/features/poster/
      // presentation/widgets/poster_sold_banner_test.dart` pins the
      // absence (the banner's button must still be a stadium).
    );
  }
}
