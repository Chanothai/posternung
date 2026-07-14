import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography tokens extracted from Figma (PosterNung — Onboarding).
abstract final class AppTextStyles {
  static final TextStyle appBarTitle = GoogleFonts.kanit(
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
  static final TextStyle skipButton = GoogleFonts.kanit(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.35,
    color: AppColors.textSecondary,
  );

  static final TextStyle heroTitle = GoogleFonts.kanit(
    fontSize: 36,
    height: 45 / 36,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static final TextStyle heroTitleEmphasis = GoogleFonts.kanit(
    fontSize: 36,
    height: 45 / 36,
    fontWeight: FontWeight.normal,
    fontStyle: FontStyle.italic,
    color: AppColors.accent,
  );

  static final TextStyle heroTitleSmall = GoogleFonts.kanit(
    fontSize: 30,
    height: 37.5 / 30,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static final TextStyle heroTitleSmallEmphasis = GoogleFonts.kanit(
    fontSize: 30,
    height: 37.5 / 30,
    fontWeight: FontWeight.normal,
    fontStyle: FontStyle.italic,
    color: AppColors.accent,
  );

  static final TextStyle badgeLabel = GoogleFonts.kanit(
    fontSize: 10.4,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.04,
    color: AppColors.textSecondary,
  );

  static final TextStyle stockBadgeLabel = GoogleFonts.kanit(
    fontSize: 8,
    height: 12 / 8,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.accent,
  );

  static final TextStyle bodyDescription = GoogleFonts.kanit(
    fontSize: 16,
    height: 26 / 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static final TextStyle primaryButton = GoogleFonts.kanit(
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.45,
    color: AppColors.white,
  );

  // --- Auth (login/register) ---

  static final TextStyle brandTitleLarge = GoogleFonts.kanit(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
    color: AppColors.textPrimary,
  );

  static final TextStyle authCardHeading = GoogleFonts.kanit(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static final TextStyle cardSubtitle = GoogleFonts.kanit(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static final TextStyle inputLabel = GoogleFonts.kanit(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.6,
    color: AppColors.textSecondary,
  );

  static final TextStyle inputText = GoogleFonts.kanit(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.surfaceDark,
  );

  static final TextStyle linkSmall = GoogleFonts.kanit(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.normal,
    color: AppColors.accent,
  );

  static final TextStyle linkBold = GoogleFonts.kanit(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.bold,
    color: AppColors.accent,
  );

  static final TextStyle authButtonLabel = GoogleFonts.kanit(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.4,
    color: AppColors.white,
  );

  static final TextStyle dividerLabel = GoogleFonts.kanit(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.normal,
    letterSpacing: 1.2,
    color: AppColors.textPrimary,
  );

  // --- Home ---

  static final TextStyle homeSectionHeading = GoogleFonts.kanit(
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static final TextStyle homeCollectionEyebrow = GoogleFonts.kanit(
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
    color: AppColors.accent,
  );

  static final TextStyle homeCollectionTitle = GoogleFonts.kanit(
    fontSize: 18,
    height: 22.5 / 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static final TextStyle homeSearchPlaceholder = GoogleFonts.kanit(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.placeholderGray,
  );

  static final TextStyle homePosterTitle = GoogleFonts.kanit(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static final TextStyle homePosterSubtitle = GoogleFonts.kanit(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static final TextStyle homePosterPrice = GoogleFonts.kanit(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static final TextStyle homeConditionTag = GoogleFonts.kanit(
    fontSize: 9,
    height: 13.5 / 9,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static final TextStyle homeBadgeLabel = GoogleFonts.kanit(
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.bold,
    color: AppColors.white,
  );

  static final TextStyle homeLoadMoreLabel = GoogleFonts.kanit(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static final TextStyle homeNavTabLabel = GoogleFonts.kanit(
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.25,
    color: AppColors.textPrimary,
  );
}
