/// Sizing tokens for icons, avatars, buttons, and cards.
abstract final class AppDimens {
  AppDimens._();

  static const double iconSm = 16;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double buttonHeight = 48;
  static const double avatarSize = 40;

  /// Smallest square a tappable control may occupy (iOS HIG / Material both
  /// land here). Use it whenever an icon is the whole target — an
  /// [iconMd] glyph on its own is only 24 and misses far more taps than it
  /// looks like it should.
  static const double minTouchTarget = 44;

  /// Width:height ratio (2:3) for a poster card's image block.
  static const double posterCardAspectRatio = 2 / 3;
}
