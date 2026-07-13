import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography tokens extracted from Figma (Cinevault 2 — Onboarding).
abstract final class AppTextStyles {
  static TextStyle get appBarTitle => GoogleFonts.libreBaskerville(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
    color: AppColors.textPrimary,
  );

  static TextStyle get skipButton => GoogleFonts.libreBaskerville(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.35,
    color: AppColors.textSecondary,
  );

  static TextStyle get heroTitle => GoogleFonts.lora(
    fontSize: 36,
    height: 45 / 36,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static TextStyle get heroTitleEmphasis => GoogleFonts.lora(
    fontSize: 36,
    height: 45 / 36,
    fontWeight: FontWeight.normal,
    fontStyle: FontStyle.italic,
    color: AppColors.accent,
  );

  static TextStyle get bodyDescription => GoogleFonts.libreBaskerville(
    fontSize: 16,
    height: 26 / 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static TextStyle get primaryButton => GoogleFonts.libreBaskerville(
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.45,
    color: AppColors.white,
  );
}
