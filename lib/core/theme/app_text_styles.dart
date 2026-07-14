import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography tokens extracted from Figma (PosterNung — Onboarding).
abstract final class AppTextStyles {
  static final TextStyle appBarTitle = GoogleFonts.libreBaskerville(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
    color: AppColors.textPrimary,
  );

  // Thai text has no glyphs in Lora/Libre Baskerville/IBM Plex Mono — Flutter
  // silently falls back to a generic system font for it, breaking the
  // vintage-editorial look. These fields use Thai-covering families chosen
  // to stay close to the original serif/mono character instead.
  static final TextStyle skipButton = GoogleFonts.sarabun(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.35,
    color: AppColors.textSecondary,
  );

  static final TextStyle heroTitle = GoogleFonts.notoSerifThai(
    fontSize: 36,
    height: 45 / 36,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static final TextStyle heroTitleEmphasis = GoogleFonts.notoSerifThai(
    fontSize: 36,
    height: 45 / 36,
    fontWeight: FontWeight.normal,
    fontStyle: FontStyle.italic,
    color: AppColors.accent,
  );

  static final TextStyle heroTitleSmall = GoogleFonts.notoSerifThai(
    fontSize: 30,
    height: 37.5 / 30,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static final TextStyle heroTitleSmallEmphasis = GoogleFonts.notoSerifThai(
    fontSize: 30,
    height: 37.5 / 30,
    fontWeight: FontWeight.normal,
    fontStyle: FontStyle.italic,
    color: AppColors.accent,
  );

  static final TextStyle badgeLabel = GoogleFonts.sarabun(
    fontSize: 10.4,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.04,
    color: AppColors.textSecondary,
  );

  static final TextStyle stockBadgeLabel = GoogleFonts.sarabun(
    fontSize: 8,
    height: 12 / 8,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.accent,
  );

  static final TextStyle bodyDescription = GoogleFonts.sarabun(
    fontSize: 16,
    height: 26 / 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static final TextStyle primaryButton = GoogleFonts.sarabun(
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.45,
    color: AppColors.white,
  );

  // --- Auth (login/register) ---

  static final TextStyle brandTitleLarge = GoogleFonts.libreBaskerville(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
    color: AppColors.textPrimary,
  );

  static final TextStyle authCardHeading = GoogleFonts.notoSerifThai(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static final TextStyle cardSubtitle = GoogleFonts.sarabun(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static final TextStyle inputLabel = GoogleFonts.sarabun(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.6,
    color: AppColors.textSecondary,
  );

  static final TextStyle inputText = GoogleFonts.sarabun(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.surfaceDark,
  );

  static final TextStyle linkSmall = GoogleFonts.sarabun(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.normal,
    color: AppColors.accent,
  );

  static final TextStyle linkBold = GoogleFonts.sarabun(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.bold,
    color: AppColors.accent,
  );

  static final TextStyle authButtonLabel = GoogleFonts.sarabun(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.4,
    color: AppColors.white,
  );

  static final TextStyle dividerLabel = GoogleFonts.sarabun(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.normal,
    letterSpacing: 1.2,
    color: AppColors.textPrimary,
  );
}
