import 'package:flutter/material.dart';

import '../catalog/poster_condition_grade.dart';

/// Design tokens extracted from Figma (PosterNung — Onboarding + Auth).
abstract final class AppColors {
  static const Color surfaceDark = Color(0xFF4A3F35);
  static const Color textPrimary = Color(0xFFF5F1E6);
  static const Color textSecondary = Color(0xFFE2D8C3);
  static const Color accent = Color(0xFFA67C52);
  static const Color white = Color(0xFFFFFFFF);
  static const Color borderMuted = Color(0xFFE5E7EB);
  static const Color placeholderGray = Color(0xFF9CA3AF);
  static const Color glassCardFill = Color(0x08FFFCF5);
  static const Color glassCardBorder = Color(0x1ADBD0BA);

  // --- Home ---
  static const Color accentRed = Color(0xFFB54A35);
  static const Color posterPlaceholderFill = Color(0x80000000);

  // --- Status views (error / empty / not found) ---
  // Low-alpha washes of the two accents, used as the halo behind a status
  // icon. Alpha rather than a flat blend so they sit correctly on both the
  // gradient background and the glass card fill.
  static const Color accentRedSoft = Color(0x24B54A35);
  static const Color accentSoft = Color(0x24A67C52);

  // --- Condition grade scale (ADR-0016 D6) ---
  //
  // 🔴 round-1 code-critic history (2026-08-06): the first version of this
  // palette was ColorBrewer's "RdYlGn" 8-class diverging ramp. That's
  // wrong for two independent reasons, and both had to be fixed together
  // (fixing one alone doesn't fix the other):
  //   1. RdYlGn is a *diverging* scale — its two ends (green/red) sit at
  //      similar lightness by construction, which is exactly why
  //      deuteranopia/protanopia collapse `mint` (#1A9850) and `poor`
  //      (#D73027) into each other: those color-vision types confuse
  //      red↔green hue, and with no lightness gap to fall back on, the
  //      two ends of the scale became indistinguishable.
  //   2. Its darker steps (`fair` #F46D43, `poor` #D73027) measured
  //      **2.1–2.8:1** against `surfaceDark` (#4A3F35) — below WCAG
  //      1.4.11's 3:1 non-text floor. Swapping to a colorblind-safe
  //      diverging ramp (e.g. RdYlBu) would have fixed (1) but not (2):
  //      its dark end (`#4575B4`) is just as low-luminance as RdYlGn's.
  //
  // The fix has to satisfy three things *simultaneously*, computed (not
  // eyeballed — a background this dark makes "looks fine" an unreliable
  // judge; see the luminance-floor argument below):
  //
  //   (a) a single **sequential** ramp with monotonically *decreasing*
  //       WCAG relative luminance from `mint` (best) to `poor` (worst),
  //       sweeping hue along the blue→teal→green→olive→amber diagonal —
  //       the axis colorblind-safe colormaps (e.g. cividis) use because it
  //       avoids the red↔green confusion line entirely. Monotonic
  //       luminance is the real safety net: even a viewer who can't
  //       resolve hue at all still sees the scale's order from lightness
  //       alone, and neither confusable-pair type (protanopia/deuteranopia)
  //       meaningfully disrupts luminance ordering the way it disrupts hue.
  //   (b) every one of the 8 values ≥ 3:1 against **both** backgrounds
  //       colors appear on: `surfaceDark` (#4A3F35, relative luminance
  //       ≈0.0527) and `glassCardFill` composited over it (≈(80,69,59),
  //       relative luminance ≈0.0628) — `glassCardFill` is only 8% white
  //       alpha, so it's the *stricter* of the two, not a free pass.
  //       Because `surfaceDark` is itself fairly dark, WCAG's contrast
  //       formula makes going *darker* mathematically impossible to reach
  //       3:1 (it would require negative luminance) — every value in this
  //       palette is necessarily on the *light* side of `surfaceDark`, not
  //       symmetric light/dark like a typical "grade color" scale.
  //   (c) verified against simulated protanopia/deuteranopia (Machado,
  //       Oliveira & Fluck 2009 linear-RGB matrices, severity 1.0) — every
  //       adjacent pair stays separated by simulated RGB distance ≥11.58
  //       (protanopia) / ≥14.73 (deuteranopia), and the two ends
  //       (`mint` vs `poor` — the pair that collapsed under RdYlGn) land
  //       ≥200 apart in both simulations.
  //
  // Computed values (hue sweep ≈207°→32°, HSL saturation ≈0.48–0.50 —
  // the lightest steps drift from the nominal 205°/0.50 target because
  // 8-bit rounding is coarse at that lightness; lightness
  // solved per-step to hit the target luminance — see the derivation
  // script referenced in this round's report, not reproduced here):
  //
  //   grade      hex      vs surfaceDark   vs glassCardFill (composited)
  //   mint       #EEF4F9  9.22:1           8.40:1
  //   nearMint   #DAEFF3  8.58:1           7.81:1
  //   veryFine   #C0EAE3  7.85:1           7.15:1
  //   fine       #ADE4BF  7.12:1           6.48:1
  //   veryGood   #A8DA8F  6.37:1           5.80:1
  //   good       #B6C85A  5.55:1           5.05:1
  //   fair       #C3AF4C  4.65:1           4.24:1
  //   poor       #C58E50  3.58:1           3.26:1
  //
  // 🔴 D6 still applies on top of all this: color here is a *supplementary*
  // cue only, never the sole signal of rank — every call site pairs one of
  // these with the grade's `scaleFractionLabel` ("x/8") text. Nothing in
  // this file enforces that pairing; it's enforced at each call site
  // (`condition_grade_indicator.dart`, `condition_grade_guide_sheet.dart`)
  // and pinned by their widget tests.
  static const Color conditionGradeMint = Color(0xFFEEF4F9);
  static const Color conditionGradeNearMint = Color(0xFFDAEFF3);
  static const Color conditionGradeVeryFine = Color(0xFFC0EAE3);
  static const Color conditionGradeFine = Color(0xFFADE4BF);
  static const Color conditionGradeVeryGood = Color(0xFFA8DA8F);
  static const Color conditionGradeGood = Color(0xFFB6C85A);
  static const Color conditionGradeFair = Color(0xFFC3AF4C);
  static const Color conditionGradePoor = Color(0xFFC58E50);
}

/// Maps [PosterConditionGrade] to its scale accent color (ADR-0016 D6).
///
/// Lives here rather than as a member of the enum itself because
/// `poster_condition_grade.dart` is deliberately Flutter-free (see its file
/// doc comment) so the domain layer can depend on it — this is the one
/// place a `Color` gets attached to a grade, so both
/// `ConditionGradeIndicator` and the guide sheet read the same value.
extension PosterConditionGradeColorX on PosterConditionGrade {
  Color get scaleColor => switch (this) {
    PosterConditionGrade.mint => AppColors.conditionGradeMint,
    PosterConditionGrade.nearMint => AppColors.conditionGradeNearMint,
    PosterConditionGrade.veryFine => AppColors.conditionGradeVeryFine,
    PosterConditionGrade.fine => AppColors.conditionGradeFine,
    PosterConditionGrade.veryGood => AppColors.conditionGradeVeryGood,
    PosterConditionGrade.good => AppColors.conditionGradeGood,
    PosterConditionGrade.fair => AppColors.conditionGradeFair,
    PosterConditionGrade.poor => AppColors.conditionGradePoor,
  };
}
