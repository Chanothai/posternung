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

  // --- Auth: method tabs (email / phone) ---
  static const String authMethodEmailTab = 'อีเมล';
  static const String authMethodPhoneTab = 'เบอร์โทรศัพท์';
  static const String authPhoneLabel = 'หมายเลขโทรศัพท์';
  static const String authPhoneHint = '81 234 5678';
  static const String authPhoneValidationError = 'กรอกเบอร์โทรศัพท์ให้ถูกต้อง';
  static const String authPhoneHeading = 'เข้าสู่ระบบด้วยเบอร์โทรศัพท์';
  static const String authPhoneSubtitle = 'กรอกเบอร์โทรศัพท์เพื่อรับรหัสยืนยัน';
  static const String authSubmitPhoneOtp = 'ส่งรหัส OTP';

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

  // --- Auth: OTP verification ---
  static const String authOtpHeading = 'ยืนยันเบอร์โทรศัพท์ของคุณ';
  static const String authOtpSubtitlePrefix = 'กรอกรหัส 6 หลักที่เราส่งไปยัง';
  static const String authOtpResendPrompt = 'ไม่ได้รับรหัส? ';
  static const String authOtpResendAction = 'ส่งรหัสอีกครั้ง';
  static const String authOtpResendCountdownPrefix = 'ส่งรหัสอีกครั้งได้ใน ';
  static const String authOtpResendCountdownSuffix = ' วินาที';

  // --- Auth error display (friendly Thai message + raw code) ---
  // Shown on the login screen when sign-in fails. The raw error code is
  // rendered on a second line prefixed with authErrorCodeLabel; the message
  // is a friendly Thai line — mapped per known Firebase code below, or taken
  // straight from the backend's already-Thai `{error_code, message}` envelope.
  static const String authErrorCodeLabel = 'รหัสข้อผิดพลาด: ';
  static const String authErrorGeneric = 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
  static const String authErrorNetwork =
      'เชื่อมต่อเครือข่ายไม่สำเร็จ กรุณาตรวจสอบอินเทอร์เน็ต';
  static const String authErrorServer =
      'เซิร์ฟเวอร์ขัดข้อง กรุณาลองใหม่ภายหลัง';
  // Firebase (email/password) codes → Thai.
  static const String authErrorInvalidEmail = 'อีเมลไม่ถูกต้อง';
  static const String authErrorUserDisabled = 'บัญชีนี้ถูกระงับการใช้งาน';
  static const String authErrorUserNotFound = 'ไม่พบบัญชีผู้ใช้นี้';
  static const String authErrorWrongPassword = 'รหัสผ่านไม่ถูกต้อง';
  static const String authErrorInvalidCredential =
      'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
  // Flow-neutral wording — the same Firebase code covers both too-many
  // login attempts and too-many SMS sends.
  static const String authErrorTooManyRequests =
      'ทำรายการบ่อยเกินไป กรุณาลองใหม่ภายหลัง';
  static const String authErrorEmailAlreadyInUse = 'อีเมลนี้ถูกใช้สมัครแล้ว';
  static const String authErrorWeakPassword = 'รหัสผ่านคาดเดาง่ายเกินไป';
  static const String authErrorOperationNotAllowed =
      'ยังไม่เปิดใช้งานวิธีเข้าสู่ระบบนี้';
  // Firebase (phone) codes → Thai.
  static const String authErrorInvalidPhoneNumber = 'หมายเลขโทรศัพท์ไม่ถูกต้อง';
  static const String authErrorInvalidVerificationCode = 'รหัสยืนยันไม่ถูกต้อง';
  static const String authErrorInvalidVerificationId =
      'รหัสยืนยันหมดอายุ กรุณาขอรหัสใหม่';
  static const String authErrorMissingVerificationCode = 'กรุณากรอกรหัสยืนยัน';
  static const String authErrorSessionExpired = 'เซสชันหมดอายุ กรุณาขอรหัสใหม่';
  static const String authErrorQuotaExceeded =
      'ระบบส่ง SMS เต็มโควตาชั่วคราว กรุณาลองใหม่ภายหลัง';
  static const String authErrorMissingClientIdentifier =
      'ไม่สามารถยืนยันตัวตนแอปได้ กรุณาลองใหม่อีกครั้ง';
  static const String authErrorCaptchaCheckFailed =
      'ยืนยันตัวตนไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
  static const String authErrorCredentialAlreadyInUse =
      'หมายเลขนี้ถูกใช้กับบัญชีอื่นแล้ว';
  // Firebase (social — Google/Apple) codes → Thai.
  static const String authErrorAccountExistsWithDifferentCredential =
      'อีเมลนี้เคยสมัครไว้ด้วยวิธีอื่นแล้ว กรุณาเข้าสู่ระบบด้วยวิธีเดิม';

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
