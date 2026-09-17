import 'package:flutter/material.dart';

import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';

/// The white auth inputs' own decoration values — email, password and phone
/// (`AuthEmailField` · `AuthPasswordField` · `LoginScreen`'s `_PhoneField`).
///
/// Since SCR-07 B9 the app-wide `InputDecorationThemeData` (`AppTheme`)
/// paints the dark-ground inputs: `fillColor` `inputFill`, resting border
/// `inputBorder` (white at 10%), and a 16/12 `contentPadding`. The auth
/// cards keep their **white** fields, so under that theme they would get
/// a white-on-white resting border — invisible — and lose 8px of height
/// (56 → 48). A decoration setting only `border:` cannot fix this: under
/// Material 3 `InputDecorator` resolves an unfocused field to
/// `enabledBorder` (theme's, if the widget set none) and, when that is
/// also null, swaps `border:`'s side for the theme's `activeIndicatorBorder`
/// — the colour named on `border:` never paints (SCR-02 gap N-1). So every
/// state border is set here explicitly, and `border:` is deliberately not
/// used at all.
///
/// Colours: resting `borderMuted`, focused `accent`, error `accentRed` —
/// the Figma auth card values these widgets always named (and, before
/// B9, never actually rendered).
abstract final class AuthInputBorders {
  AuthInputBorders._();

  static OutlineInputBorder _outline(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.xs),
    borderSide: BorderSide(color: color),
  );

  static final OutlineInputBorder enabled = _outline(AppColors.borderMuted);
  static final OutlineInputBorder focused = _outline(AppColors.accent);
  static final OutlineInputBorder error = _outline(AppColors.accentRed);
  static final OutlineInputBorder disabled = _outline(AppColors.borderMuted);

  /// 16 all round → 56px tall with the 24px input line — the height the
  /// auth fields had before the theme's `contentPadding` existed (email /
  /// password used Flutter's M3 outline default `20/12` top/bottom = the
  /// same 56; phone already set `lg` vertical explicitly).
  static const EdgeInsets contentPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.lg,
  );
}
