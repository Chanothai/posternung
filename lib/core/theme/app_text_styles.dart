import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography tokens extracted from Figma (PosterNung — Onboarding).
abstract final class AppTextStyles {
  static TextStyle get appBarTitle => GoogleFonts.libreBaskerville(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
    color: AppColors.textPrimary,
  );

  // Thai text has no glyphs in Lora/Libre Baskerville/IBM Plex Mono — Flutter
  // silently falls back to a generic system font for it, breaking the
  // vintage-editorial look. These getters use Thai-covering families chosen
  // to stay close to the original serif/mono character instead.
  static TextStyle get skipButton => GoogleFonts.sarabun(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.35,
    color: AppColors.textSecondary,
  );

  static TextStyle get heroTitle => GoogleFonts.notoSerifThai(
    fontSize: 36,
    height: 45 / 36,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static TextStyle get heroTitleEmphasis => GoogleFonts.notoSerifThai(
    fontSize: 36,
    height: 45 / 36,
    fontWeight: FontWeight.normal,
    fontStyle: FontStyle.italic,
    color: AppColors.accent,
  );

  static TextStyle get heroTitleSmall => GoogleFonts.notoSerifThai(
    fontSize: 30,
    height: 37.5 / 30,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static TextStyle get heroTitleSmallEmphasis => GoogleFonts.notoSerifThai(
    fontSize: 30,
    height: 37.5 / 30,
    fontWeight: FontWeight.normal,
    fontStyle: FontStyle.italic,
    color: AppColors.accent,
  );

  static TextStyle get badgeLabel => GoogleFonts.chakraPetch(
    fontSize: 10.4,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.04,
    color: AppColors.textSecondary,
  );

  static TextStyle get bodyDescription => GoogleFonts.sarabun(
    fontSize: 16,
    height: 26 / 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static TextStyle get primaryButton => GoogleFonts.sarabun(
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.45,
    color: AppColors.white,
  );
}
