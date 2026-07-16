/// Corner-radius tokens for consistent rounding across the app.
abstract final class AppRadius {
  AppRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;

  /// Fully rounded (pill) shape — matches the `BorderRadius.circular(9999)`
  /// value already used across the codebase for pill buttons/search bars.
  static const double full = 9999;
}
