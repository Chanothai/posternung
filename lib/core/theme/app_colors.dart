import 'package:flutter/material.dart';

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
}
