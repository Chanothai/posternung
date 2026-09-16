/// Image asset paths centralized from the Figma-exported `assets/images/`
/// folder (PosterNung — Onboarding, Auth, Home).
abstract final class AppImages {
  static const String headerIcon = 'assets/images/header_icon.svg';
  static const String posterPlaceholderIcon =
      'assets/images/poster_placeholder_icon.svg';
  static const String arrowRight = 'assets/images/arrow_right.svg';

  // --- Onboarding ---
  /// The centrepiece glyph on onboarding page 2: a question mark inside a
  /// dashed ring. Named after what the artwork *is*, not after the caption it
  /// used to sit under: it kept a name meaning "verified badge" long after the
  /// "ยืนยันแล้ว" label was removed under ADR-0014 D1, and a name that still
  /// asserts the goods are certified is an invitation to put that banned
  /// claim back on screen (BL-74).
  static const String questionMarkDashedCircleIcon =
      'assets/images/question_mark_dashed_circle_icon.svg';

  // --- Auth ---
  static const String emailIcon = 'assets/images/email_icon.svg';
  static const String lockIcon = 'assets/images/lock_icon.svg';
  static const String eyeIcon = 'assets/images/eye_icon.svg';
  static const String googleLogo = 'assets/images/google_logo.svg';
  // `appleLogo` removed under ADR-0021 D4 — Sign in with Apple was deleted
  // end-to-end. The svg asset itself is left in assets/images/ untouched;
  // only the button that referenced this constant is gone.

  // --- Home ---
  static const String heartIcon = 'assets/images/heart_icon.svg';
  static const String cartIcon = 'assets/images/cart_icon.svg';
  static const String searchIcon = 'assets/images/search_icon.svg';
  static const String filterIcon = 'assets/images/filter_icon.svg';
  static const String navHomeIcon = 'assets/images/nav_home_icon.svg';
  // `navSearchIcon`/`navWishlistIcon`/`navCartIcon` removed under SCR-07 B7
  // (`ADR-0037` Amendment 1 — bottom nav cut to 3 tabs: search/wishlist/cart
  // have no schema or endpoint behind them). The orders tab that replaced
  // them uses `Icons.receipt_long_outlined` rather than a new asset.
  static const String navProfileIcon = 'assets/images/nav_profile_icon.svg';
}
