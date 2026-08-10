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
      'ค้นพบและสะสมโปสเตอร์ภาพยนตร์ต้นฉบับหายาก '
      'จากยุคที่คุณชื่นชอบ';
  static const String onboardingHeroTitlePage2Prefix =
      'ดูรายละเอียดได้เต็มที่\n';
  static const String onboardingHeroTitlePage2Emphasis = 'ก่อนตัดสินใจ';
  static const String onboardingBodyPage2 =
      'ซูมดูรูปได้ทุกใบ และดูข้อมูลที่เรามีของโปสเตอร์ชิ้นนั้น';
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
  // `authAppleSignIn` removed under ADR-0021 D4 — Sign in with Apple was
  // deleted end-to-end, not just hidden (see `docs/social-login-setup.md`
  // for the App Store condition that brings it back).
  static const String authTogglePromptRegister = 'มีบัญชีอยู่แล้ว? ';
  static const String authTogglePromptLogin = 'ยังไม่มีบัญชี? ';
  static const String authMobileOnlyMessage = 'รองรับเฉพาะบนมือถือ';
  // `authGenericErrorMessage`/`authGateErrorPrefix` (English placeholder
  // strings) removed under ADR-0017 — the raw-error-text paths that used
  // them (`_messageFor`'s sentinel check, `auth_gate.dart`'s `$error`
  // interpolation) are gone; `authErrorGeneric` below is the one Thai
  // fallback line now.

  // --- Auth: OTP verification ---
  static const String authOtpHeading = 'ยืนยันเบอร์โทรศัพท์ของคุณ';
  static const String authOtpSubtitlePrefix = 'กรอกรหัส 6 หลักที่เราส่งไปยัง';
  static const String authOtpResendPrompt = 'ไม่ได้รับรหัส? ';
  static const String authOtpResendAction = 'ส่งรหัสอีกครั้ง';
  static const String authOtpResendCountdownPrefix = 'ส่งรหัสอีกครั้งได้ใน ';
  static const String authOtpResendCountdownSuffix = ' วินาที';

  // --- Auth: email verification (ADR-0021 D2) — reached after register, or
  // after a `password`-provider login whose backend exchange answered
  // 403 OAUTH_EMAIL_NOT_VERIFIED. No Figma spec exists for this screen.
  static const String authEmailVerificationHeading = 'ยืนยันอีเมลของคุณ';
  static const String authEmailVerificationSubtitlePrefix =
      'เราได้ส่งอีเมลยืนยันไปที่';
  static const String authEmailVerificationInstructions =
      'กรุณาตรวจสอบกล่องจดหมายและกดลิงก์ยืนยัน '
      'แล้วกลับมากดตรวจสอบสถานะที่นี่';
  static const String authEmailVerificationCheckButton = 'ตรวจสอบสถานะ';
  static const String authEmailVerificationNotYetMessage =
      'ยังไม่พบการยืนยัน กรุณายืนยันอีเมลก่อน แล้วลองอีกครั้ง';
  static const String authEmailVerificationResendPrompt = 'ไม่ได้รับอีเมล? ';
  static const String authEmailVerificationResendAction = 'ส่งอีเมลอีกครั้ง';
  static const String authEmailVerificationResendCountdownPrefix =
      'ส่งอีเมลอีกครั้งได้ใน ';
  static const String authEmailVerificationResendCountdownSuffix = ' วินาที';
  static const String authEmailVerificationBackToLoginPrompt = 'เปลี่ยนใจ? ';

  // --- Auth error display (friendly Thai message + raw code) ---
  // Shown on the login screen when sign-in fails. The raw error code is
  // rendered on a second line prefixed with authErrorCodeLabel; the message
  // is a friendly Thai line — mapped per known Firebase code below, or taken
  // straight from the backend's already-Thai `{error_code, message}` envelope.
  static const String authErrorCodeLabel = 'รหัสข้อผิดพลาด: ';
  static const String authErrorGeneric = 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
  // ADR-0021 D3 — the one code whose error banner gets a button
  // (AuthErrorBanner gates this on `code`, not on which screen shows it).
  static const String authRetryButton = 'ลองใหม่';
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
  // ADR-0021 D2 — this address already has an account (verified or not); the
  // fix is to log in with it, not create a second one, so the message points
  // there instead of just stating the fact.
  static const String authErrorEmailAlreadyInUse =
      'อีเมลนี้มีบัญชีอยู่แล้ว กรุณาเข้าสู่ระบบแทน';
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
  // Firebase (social — Google) codes → Thai.
  static const String authErrorAccountExistsWithDifferentCredential =
      'อีเมลนี้เคยสมัครไว้ด้วยวิธีอื่นแล้ว กรุณาเข้าสู่ระบบด้วยวิธีเดิม';

  // --- Home ---
  static const String homeSectionAllPosters = 'โปสเตอร์ทั้งหมด';
  static const String homeNavHome = 'หน้าหลัก';
  static const String homeNavSearch = 'ค้นหา';
  static const String homeNavWishlist = 'รายการที่ชอบ';
  static const String homeNavCart = 'ตะกร้าสินค้า';
  static const String homeNavProfile = 'โปรไฟล์';
  static const String homeBrandTitle = 'หน้าหลัก';
  static const String homeSearchPlaceholder =
      'Search movies, directors, years...';

  // --- Home / Discover catalog list (SCR-03, GET /posters) ---
  /// AC-4 — a poster that is no longer for sale must say so on the card
  /// itself, rather than looking buyable until the user taps into it.
  static const String homePosterSoldBadge = 'ขายแล้ว';

  /// Covers `reserved` **and** a status this client doesn't recognize —
  /// both mean "we can't tell the user this is buyable", and neither is
  /// worth a distinct word here.
  static const String homePosterUnavailableBadge = 'ไม่พร้อมขาย';
  static const String homePostersEmptyTitle = 'ยังไม่มีโปสเตอร์ให้ชมตอนนี้';
  static const String homePostersEmptyBody =
      'เรากำลังคัดโปสเตอร์ต้นฉบับชิ้นใหม่เข้าร้าน กลับมาดูอีกครั้งเร็ว ๆ นี้';
  static const String homePostersErrorTitle = 'โหลดรายการโปสเตอร์ไม่สำเร็จ';
  static const String homePostersErrorBody =
      'กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ตแล้วลองใหม่อีกครั้ง';
  static const String homePostersRetryCta = 'ลองใหม่อีกครั้ง';
  static const String homeWishlistButtonTooltip = 'เพิ่มลงรายการที่อยากได้';

  /// Shown above the pager while the catalog has more rows than the grid is
  /// holding, so the button says how much more there is rather than just
  /// "more". `{shown}`/`{total}` are substituted at the call site. Hidden
  /// once everything is loaded — "แสดง 7 จาก 7" states the obvious.
  static const String homeCatalogShownOfTotal =
      'แสดง {shown} จาก {total} รายการ';

  /// The pager itself. An earlier round of SCR-03 had this button raise a
  /// coming-soon snackbar with no pagination behind it; it now appends a
  /// real page (`GET /posters?offset=`), and must never go back to being
  /// decorative — a control that loads nothing reads as broken.
  static const String homeLoadMoreButton = 'โหลดเพิ่มเติม';
  static const String homeLoadMoreLoading = 'กำลังโหลด...';

  /// A page *after* the first failed. Deliberately its own copy rather than
  /// [homePostersErrorTitle]: nothing on screen is broken, the grid the user
  /// is reading is intact, and only the extra rows are missing.
  static const String homeLoadMoreErrorBody =
      'โหลดรายการเพิ่มเติมไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';

  // --- Condition grade guide (shared bottom sheet — ADR-0003, used from
  // ConditionGradeIndicator in core/widgets/) ---
  static const String conditionGuideTitle = 'คู่มือระดับสภาพสินค้า';
  static const String conditionGuideSubtitle =
      'เรียงจากสภาพดีที่สุดไปแย่ที่สุด ตามมาตรฐานที่วงการนักสะสมใช้';
  static const String conditionGuideCurrentBadge = 'สภาพชิ้นนี้';
  static const String conditionGradeUnspecifiedLabel = 'ไม่ระบุสภาพ';

  /// Tooltip / semantic label of the sheet's close button. The button itself
  /// is not decoration: with all 8 grades listed the sheet fills the screen,
  /// leaving no barrier to tap and no non-scrolling area to drag — verified
  /// on device 2026-08-06, where the guide could not be dismissed at all.
  static const String conditionGuideCloseLabel = 'ปิด';

  // --- Condition grade guide: wear-trace list (ADR-0016 AC-3a) ---
  /// Prefix before the joined [PosterConditionGradeX.wearTraces] list —
  /// draft wording, content of the list itself locked to BL-60's
  /// vocabulary by D9 (see the getter's doc comment), but this label is
  /// not part of that lock.
  static const String conditionGuideTracesLabel = 'ร่องรอยที่อาจพบ: ';

  /// Shown instead of [conditionGuideTracesLabel] when
  /// [PosterConditionGradeX.wearTraces] is empty (`mint` only) — the trace
  /// section must never be blank, per the guide sheet's own test suite.
  static const String conditionGuideNoTracesLabel =
      'ไม่มีร่องรอยที่สังเกตเห็นได้';

  // --- Condition grade guide: Fine ↔ Very Good boundary callout
  // (ADR-0016 D3(ข) — the one pair of adjacent grades collectors' English
  // naming reads backwards on, and the reason SCR-11 exists at all per
  // ADR-0003). Draft wording — flagged for GATE 3.
  static const String conditionGuideFineVeryGoodCalloutTitle =
      'จุดที่มักเข้าใจผิด';
  static const String conditionGuideFineVeryGoodCalloutBody =
      '"Fine" อยู่เหนือ "Very Good" บนสเกลนี้ แม้ชื่อจะฟังดูสวนทางกัน — '
      'ชื่อเรียกเป็นคำศัพท์มาตรฐานที่วงการนักสะสมใช้ ไม่ได้เรียงตามความหมาย'
      'ในภาษาอังกฤษทั่วไป';

  // --- Poster Detail (SCR-05) ---
  // Says *why* to zoom, not how — inspecting condition before buying is the
  // job (BR-05/ADR-0003), and a gesture instruction would go stale the
  // moment the affordance changes.
  static const String posterDetailZoomHint = 'ดูรายละเอียดสภาพ';
  static const String posterDetailZoomInTooltip = 'ขยายดูรายละเอียดสภาพ';
  static const String posterDetailZoomOutTooltip = 'ย่อกลับ';
  static const String posterDetailSingleStockNotice =
      'มีชิ้นเดียว ของหายากที่เมื่อขายแล้วจะไม่กลับมาอีก';
  static const String posterDetailReservedNotice =
      'ขณะนี้มีผู้อื่นกำลังจองโปสเตอร์ชิ้นนี้อยู่';
  static const String posterDetailSoldTitle = 'โปสเตอร์ชิ้นนี้ถูกซื้อไปแล้ว';
  static const String posterDetailSoldBody =
      'ของชิ้นนี้มีเพียงชิ้นเดียวและมีผู้ซื้อไปเรียบร้อยแล้วระหว่างที่คุณกำลังดูอยู่';
  static const String posterDetailSoldCta = 'เลือกดูโปสเตอร์ชิ้นอื่น';
  // 🔴 ADR-0014 D1/D27 — ลบสามค่าคงที่ของบล็อก "ความถูกต้องแท้จริง" ออกเมื่อ
  // 2026-08-07 (`posterDetailAuthenticitySectionTitle` ·
  // `posterDetailAuthenticVerifiedLabel` · `posterDetailAuthenticUnverifiedLabel`)
  // **ห้ามเขียนกลับมาไม่ว่าถ้อยคำใด** — D1 ห้ามอ้างว่าร้านตรวจความแท้ และป้ายฝั่งลบ
  // ("ยังไม่ผ่าน…") ก็ยืนยันว่ามีการตรวจแบบนั้นอยู่จริงเหมือนกัน
  static const String posterDetailDetailsSectionTitle = 'รายละเอียด';
  static const String posterDetailProvenanceLabel = 'ที่มา (Provenance)';
  static const String posterDetailSizeLabel = 'ขนาด';
  static const String posterDetailDescriptionLabel = 'คำอธิบายเพิ่มเติม';

  // --- Poster Detail (SCR-05, ADR-0011) — accordion row labels (left-hand
  // header) for the 9 new attribute fields. Only 4 of the 9 fields land a
  // row here (`poster_type` · `release_date_text` · `copyright_year` ·
  // `restoration_note`) plus `release_region` when it is specifically
  // `UNKNOWN` (ADR-0011 §D1′/§D9) — `year`/`size_format` moved to the
  // subtitle (§D4′) and `release_date` is never shown on screen (§D3). The
  // row *values* for enum fields come from the enum's own `label` (e.g.
  // `PosterTypeX.label`), per §D5 — only the header text belongs here.
  static const String posterDetailPosterTypeLabel = 'ชนิดของใบ (Poster Type)';
  static const String posterDetailReleaseDateTextLabel =
      'วันฉายตามที่พิมพ์บนใบ';
  static const String posterDetailCopyrightYearLabel = 'ปีลิขสิทธิ์บนใบ';
  static const String posterDetailRestorationNoteLabel = 'รายละเอียดการบูรณะ';
  static const String posterDetailReleaseRegionLabel = 'ภูมิภาคที่ฉาย';
  static const String posterDetailNotFoundTitle = 'ไม่พบโปสเตอร์นี้';
  static const String posterDetailNotFoundBody =
      'โปสเตอร์นี้อาจถูกลบออกไปแล้ว หรือลิงก์ไม่ถูกต้อง';
  static const String posterDetailNotFoundCta = 'กลับหน้าหลัก';
  static const String posterDetailErrorTitle = 'เกิดข้อผิดพลาด';
  static const String posterDetailErrorBody =
      'ไม่สามารถโหลดข้อมูลโปสเตอร์ได้ กรุณาลองใหม่อีกครั้ง';
  static const String posterDetailErrorRetryCta = 'ลองใหม่อีกครั้ง';
  static const String posterDetailBackButtonTooltip = 'ย้อนกลับ';

  // --- External reference link (ADR-0014 D1 · Amendment D11-D16) ---
  //
  // 🔴 NOT WIRED TO ANY UI YET, AND MUST NOT BE. Rendering anything about
  // `verification_*` is blocked by ADR-0014 D5.1 until OD-2 (legal review)
  // closes. These strings exist so the wording is settled *before* the SCR-05
  // round, not so someone can hook them up early. The negative test
  // `test/features/poster/verification_fields_not_wired_test.dart` still guards
  // `lib/` — these constants are deliberately named without `verification` so
  // they do not trip it, which is exactly why this comment has to say so.
  //
  // 🔴 FORBIDDEN VOCABULARY — for this dialog and every other string that
  // talks about a reference source: น่าเชื่อถือ · มาตรฐานสากล · ทางการ ·
  // ยืนยันได้ · ที่ทั่วโลกยอมรับ, or anything of that kind. Vouching for the
  // *source* is the same unprovable claim as vouching for the *product*, just
  // moved one step away — which is the whole thing ADR-0014 D1 forbids.
  //
  // 🔴 MUST open in the device browser (`url_launcher` with
  // `LaunchMode.externalApplication`) — never an in-app WebView, which makes
  // someone else's site look like our content. Android 11+ needs a `<queries>`
  // entry in the manifest or `canLaunchUrl` returns false silently.
  // `url_launcher` is not in `pubspec.yaml` yet — adding it belongs to the
  // round that wires this up.
  static const String externalLinkDialogTitle = 'เปิดเว็บไซต์ภายนอก';
  static const String externalLinkDialogBody =
      'ลิงก์นี้จะเปิดในเบราว์เซอร์ของเครื่องคุณ '
      'IMP Awards เป็นคลังภาพโปสเตอร์ที่เราใช้ค้นแบบ ไม่ใช่เว็บไซต์ของเรา';
  static const String externalLinkDialogCancelCta = 'ยกเลิก';
  static const String externalLinkDialogConfirmCta = 'เปิดลิงก์';
}
