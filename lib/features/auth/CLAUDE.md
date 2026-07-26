# lib/features/auth/

Fully feature-first — the reference implementation of the whole Repository + UseCase chain described in root `CLAUDE.md`. Read this feature's source before building the same chain for a new feature.

**Dual-session model.** Auth runs on two coexisting sessions: the **backend JWT session** (`posternung-backend`) for email/password, register, and Google — all Firebase-mediated, exchanged at `/auth/firebase` — and **Firebase** directly for Apple. A Firebase sign-in also establishes a Firebase session as a side effect, so `sessionProvider` merges the two — the app is logged in if either has a user — and `AuthGate` watches that merged provider, not Firebase directly.

```
domain/
  entities/       # AuthUser (uid, email) — used by both sessions
  repositories/   # AuthRepository interface — Firebase ops only:
                  # signInWithApple/signOut/authStateChanges
                  # (email/password + Google are NOT here — backend-mediated)
  usecases/       # one class per Firebase action (SignInWithApple, SignOut)
data/
  datasources/    # AuthRemoteDataSource — FirebaseAuth Apple + session
                  #   lifecycle (signInWithApple/signOut/authStateChanges)
                  # EmailPasswordSignInDataSource — FirebaseAuth email/password
                  #   → Firebase ID token (backend verifies it)
                  # GoogleSignInDataSource — Google SDK → Firebase
                  #   signInWithCredential → Firebase ID token (backend verifies it)
                  # PhoneSignInDataSource — FirebaseAuth.verifyPhoneNumber
                  #   (send code / confirm code) → Firebase ID token
                  # BackendAuthDataSource — Dio → /auth/firebase, /auth/me, /auth/refresh
  models/         # TokenResponse, BackendUser (UserResponse → toEntity → AuthUser)
  repositories/   # AuthRepositoryImpl — maps FirebaseAuthException /
                  # SignInWithAppleAuthorizationException into AuthException or
                  # AuthCancelledException (user-cancel → silent)
presentation/
  providers/      # auth_providers.dart — Firebase DI graph + AuthViewModel
                  #   (AsyncNotifier<void>; signIn/signUp/signInWithGoogle/
                  #   sendPhoneCode/confirmPhoneCode all → backend session;
                  #   signInWithApple → Firebase)
                  # backend_session_provider.dart — BackendSessionNotifier
                  #   (AsyncNotifier<AuthUser?>): email/password + register +
                  #   Google + phone, all via /auth/firebase, secure-storage
                  #   tokens, /auth/me restore-on-startup, sign-out
                  # session_provider.dart — merges Firebase + backend sessions
  screens/        # LoginScreen — email/phone method tabs (email = login only;
                  #   phone = passwordless, → OtpVerificationScreen)
                  # RegisterScreen — email/password sign-up, pushed from
                  #   LoginScreen's nav link, no Google/Apple buttons
                  # OtpVerificationScreen — 6-digit code entry, confirms via
                  #   PhoneSignInDataSource → /auth/firebase; resend re-sends
                  #   a real code
  widgets/        # Shared building blocks used by 2+ auth screens:
                  #   AuthScaffold, AuthBrandHeader, AuthEmailField,
                  #   AuthPasswordField, AuthErrorBanner, AuthPrimaryButton,
                  #   AuthNavLinkRow. Screen-specific widgets (method tabs,
                  #   phone field, social buttons) stay private to their screen.
  auth_gate.dart  # gates a destination behind sessionProvider (AuthGate)
```

- **Email/password, register, Google, and phone are all Firebase-mediated, then backend-session** via the unified `POST /auth/firebase` endpoint: the client signs into Firebase (email/password → `EmailPasswordSignInDataSource.signIn`; register → `.register` = `createUserWithEmailAndPassword`; Google → `GoogleSignInDataSource` → `signInWithCredential`; phone → `PhoneSignInDataSource.sendCode`/`confirmCode` wrapping `FirebaseAuth.verifyPhoneNumber`), gets the **Firebase ID token**, and `BackendSessionNotifier._exchangeAndPublish` sends it to `/auth/firebase` (backend reads `sign_in_provider` from the token and **find-or-creates** the user). Tokens are stored via `core/network/TokenStorage` and `BackendSessionNotifier` publishes the `AuthUser`. On startup it validates a stored token via `/auth/me` (single `/auth/refresh` retry on 401). **Consequence:** any of these establishes *both* a Firebase session (which also gates the app via `authStateChangesProvider`) and the backend JWT session; `signOut` clears both. No global 401 interceptor yet, and no cleanup-on-backend-failure — add both (a half-registered Firebase account on a failed exchange is a known gap) when authenticated app API calls (posters/cart) land. `/auth/google` is deprecated — everything uses `/auth/firebase`.
- **Phone is two calls, not one**: `sendCode` returns either `SmsCodeSent(verificationId, resendToken: …)` (normal path — show the OTP screen; named to avoid colliding with `firebase_auth`'s own `PhoneCodeSent` type) or `PhoneAutoVerified(idToken)` (Android silently verified the device before any code was sent — `BackendSessionNotifier` exchanges it immediately, no OTP screen needed; `LoginScreen` is the root so `AuthGate` just reacts). `confirmCode` on the OTP screen turns the entered digits + `verificationId` into the ID token. **Resend requires threading `resendToken` back into `sendCode`'s `forceResendingToken`** — Firebase silently sends no SMS without it; `OtpVerificationScreen` holds and refreshes it locally alongside `_verificationId`. The phone field accepts the habitual Thai leading-zero form (`0812345678`); `core/utils/thai_phone_number.dart`'s `thaiMobileToE164` normalizes it before dialing. **iOS uses Firebase's reCAPTCHA fallback** (a brief Safari challenge) rather than silent APNs push — the Push Notifications/Background Modes capability was deliberately not added; see `docs/phone-auth-setup.md` for how it works and how to upgrade to silent verification later. The `ios/Runner/Info.plist` URL-scheme entry for `$(PRODUCT_BUNDLE_IDENTIFIER)` is what lets that reCAPTCHA fallback redirect back into the app — this needs no `AppDelegate`/`SceneDelegate` code because `firebase_auth` conforms to Flutter's `FlutterSceneLifeCycleDelegate` and handles the callback itself (verified in the doc, not assumed).
- **Apple is Firebase-only** (still): `AuthRepositoryImpl.signInWithApple` → `AuthRemoteDataSource` → Firebase, gating the app via the Firebase session. Not yet migrated to `/auth/firebase` (button is hidden pending native entitlements).
- Google/Apple sign-in buttons are web-guarded (`kIsWeb` → `_showMobileOnly()` snackbar) since those SDKs are mobile-only here. The Apple button is currently hidden (`showAppleButton = false` in `login_screen.dart`) pending native entitlements — see `docs/social-login-setup.md`.
- `signOut()` on `AuthViewModel` clears **both** sessions (the active one signs out, the other clears harmlessly).
- **Login errors** show a friendly Thai message + the raw code (second, muted line) via `authErrorDisplay(AuthException)` (`presentation/auth_error_display.dart`). Firebase codes (English, e.g. `wrong-password`) are mapped to Thai; the backend's `{error_code, message}` envelope (already Thai) is surfaced verbatim by `BackendAuthDataSource` and passed through. Cancellations never reach the banner (swallowed in `_runSocial`).
- `AuthGate` is the destination-agnostic gate: pass it any `WidgetBuilder` for the authenticated destination. Onboarding uses it as `AuthGate(builder: _buildHome)`.
- All user-facing copy in this feature comes from `AppStrings` (`core/strings/app_strings.dart`) — see that file's `// --- Auth ---` section. Some constants are deliberately reused across two different UI slots within this feature (e.g. `authSubmitLogin` for both the submit button and the mode-toggle link) because they're the same wording with the same meaning, just two roles.
