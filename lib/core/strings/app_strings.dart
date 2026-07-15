/// UI copy centralized from Figma (PosterNung — Onboarding, Auth, Home).
abstract final class AppStrings {
  static const String appName = 'PosterNung';
  static const String comingSoonMessage = 'ฟีเจอร์นี้กำลังจะมาเร็ว ๆ นี้';

  // --- Onboarding ---
  static const String onboardingSkipButton = 'ข้าม';
  static const String onboardingHeroTitlePage1Prefix =
      'เป็นเจ้าของชิ้นส่วนหนึ่งของ\n';
  static const String onboardingHeroTitlePage1Emphasis =
      'ประวัติศาสตร์ภาพยนตร์';
  static const String onboardingBodyPage1 =
      'ค้นพบและสะสมโปสเตอร์ภาพยนตร์ต้นฉบับหายากที่ผ่านการรับรอง '
      'จากยุคที่คุณชื่นชอบ';
  static const String onboardingVerifiedBadge = 'ยืนยันแล้ว';
  static const String onboardingHeroTitlePage2Prefix = 'รับรองความแท้ 100%\n';
  static const String onboardingHeroTitlePage2Emphasis = 'ต้นฉบับ';
  static const String onboardingBodyPage2 =
      'โปสเตอร์ทุกชิ้นผ่านการตรวจสอบอย่างเข้มงวดโดยผู้เชี่ยวชาญ '
      'พร้อมใบรับรองความแท้แบบดิจิทัลและการตรวจสอบที่มาโดยละเอียด';
  static const String onboardingHeroTitlePage3Prefix = 'สินค้ามีจำนวนจำกัด\n';
  static const String onboardingHeroTitlePage3Emphasis = '— ชิ้นเดียวในโลก';
  static const String onboardingStockBadge = 'เหลือ 1\nชิ้นสุดท้าย';
  static const String onboardingBodyPage3 =
      'ของหายากหมดเร็วมาก เมื่อโปสเตอร์ชิ้นพิเศษถูกขายไปแล้ว '
      'มันจะหายไปจากคลังตลอดกาล';
  static const String onboardingNextButton = 'ถัดไป';
  static const String onboardingGetStartedButton = 'เริ่มต้นใช้งาน';

  // --- Auth ---
  static const String authHeadingRegister = 'สร้างบัญชีใหม่';
  static const String authHeadingLogin = 'ยินดีต้อนรับกลับ';
  static const String authSubtitleRegister =
      'กรอกข้อมูลเพื่อเริ่มต้นสะสมโปสเตอร์ของคุณ';
  static const String authSubtitleLogin = 'กรอกข้อมูลของคุณเพื่อเข้าสู่คลัง';
  static const String authEmailLabel = 'อีเมลหรือเบอร์โทรศัพท์';
  static const String authEmailHint = 'you@example.com';
  static const String authEmailValidationError = 'กรอกอีเมลให้ถูกต้อง';
  static const String authPasswordLabel = 'รหัสผ่าน';
  static const String authForgotPassword = 'ลืมรหัสผ่าน?';
  static const String authPasswordHint = '••••••••';
  static const String authPasswordValidationError =
      'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
  static const String authSubmitRegister = 'สร้างบัญชี';
  static const String authSubmitLogin = 'เข้าสู่ระบบ';
  static const String authOrDivider = 'หรือดำเนินการต่อด้วย';
  static const String authGoogleSignIn = 'เข้าสู่ระบบด้วย Google';
  static const String authAppleSignIn = 'เข้าสู่ระบบด้วย Apple';
  static const String authTogglePromptRegister = 'มีบัญชีอยู่แล้ว? ';
  static const String authTogglePromptLogin = 'ยังไม่มีบัญชี? ';
  static const String authMobileOnlyMessage = 'รองรับเฉพาะบนมือถือ';
  static const String authGenericErrorMessage =
      'Something went wrong. Please try again.';
  static const String authGateErrorPrefix = 'Something went wrong: ';

  // --- Home ---
  static const String homeSectionFeaturedCollections = 'Featured Collections';
  static const String homeSectionEndingSoon = 'Ending Soon';
  static const String homeSectionAllPosters = 'All Posters';
  static const String homeViewAllLink = 'View all ';
  static const String homeLoadMoreButton = 'Load More Titles';
  static const String homeNavHome = 'Home';
  static const String homeNavSearch = 'Search';
  static const String homeNavWishlist = 'Wishlist';
  static const String homeNavCart = 'Cart';
  static const String homeNavProfile = 'Profile';
  static const String homeBrandTitle = 'Cinevault 2';
  static const String homeSearchPlaceholder =
      'Search movies, directors, years...';
}
