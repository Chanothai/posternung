# Phone Auth Setup (Firebase)

The Dart code for phone sign-in is complete and merged, but it **will not send real SMS until the console setup below is done** — none of it can be committed to the repo since it depends on account-specific console configuration. The app still builds and CI stays green without it; phone sign-in just fails at runtime until these steps are finished. Same pattern as `docs/social-login-setup.md` for Google/Apple — read that file too if you haven't done its Android SHA-fingerprint step yet, since phone auth reuses it.

> **How the code is wired.** `EmailPasswordSignInDataSource`/`GoogleSignInDataSource` aren't the only producers of a Firebase ID token anymore — `PhoneSignInDataSource` is a third. `FirebaseAuth.verifyPhoneNumber` sends the SMS and returns a `verificationId`; entering the code (`PhoneAuthProvider.credential` → `signInWithCredential`) yields a Firebase ID token exactly like the other two flows, which `BackendSessionNotifier._exchangeAndPublish` sends to the same `POST /api/v1/auth/firebase` endpoint. **No new backend endpoint was needed** — the backend already reads `sign_in_provider` off whatever token it's handed. See `lib/features/auth/data/datasources/phone_sign_in_data_source.dart` and `lib/features/auth/presentation/screens/otp_verification_screen.dart`.
>
> **iOS APNs was deliberately skipped.** Firebase Phone Auth on iOS normally uses a silent APNs push to verify the device without any user-visible challenge, but that requires the Push Notifications + Background Modes capability (Xcode) plus an APNs auth key uploaded to Firebase Console — both skipped this round to avoid touching entitlements/provisioning. Without it, Firebase's SDK **automatically falls back** to its own Safari-based reCAPTCHA verification (a brief webview challenge) — this works standalone and needs no Developer Portal step. Step 3 below walks through exactly what makes that fallback work and why. Add the APNs capability later if you want the silent path — see the note at the bottom of step 3.

Bundle ID / package name: `com.frameshine.posternung` (production; sit/uat append `.sit`/`.uat` — see the per-flavor table in step 3).

---

## 1. Firebase Console — enable the Phone provider

[Firebase Console](https://console.firebase.google.com/project/posternung) → **Authentication → Sign-in method** → enable **Phone**.

While there, also set **Authentication → Settings → SMS region policy** to **Allow** only Thailand (`+66`). The app only ever dials `+66` numbers (`lib/core/utils/thai_phone_number.dart` hardcodes the prefix), so there's no reason to leave the door open to other countries — this is a standard defense against SMS-pumping fraud, where a bot script requests OTPs to premium-rate numbers in other countries to rack up SMS charges on your Firebase bill.

## 2. Android — SHA fingerprints (already covered, verify only)

Phone Auth's Play Integrity check on Android uses the **same** SHA-1/SHA-256 fingerprints Google Sign-In already needs (`docs/social-login-setup.md`, step 5). If that step is done, Android needs no further setup for phone auth. If you haven't registered fingerprints yet, do that step first — there's nothing phone-auth-specific to add on top of it.

**Gotcha:** `android/app/build.gradle.kts` has no `signingConfigs` block — `release` builds reuse `signingConfigs.getByName("debug")`, i.e. **every build, including release, signs with the debug keystore** today. So the fingerprint that actually matters to Firebase right now is the debug one; registering a separate release-keystore fingerprint (and doing nothing else) will silently not help Phone Auth until real release signing is set up.

## 3. iOS — the reCAPTCHA-fallback URL scheme, step by step

`ios/Runner/Info.plist` already has this entry (a second `<dict>` inside the existing `CFBundleURLTypes` array, alongside Google Sign-In's `$(REVERSED_CLIENT_ID)` entry):

```xml
<dict>
    <!-- Redirect target for Firebase Phone Auth's reCAPTCHA-verification
         fallback (used when APNs silent verification isn't configured). -->
    <key>CFBundleURLSchemes</key>
    <array>
        <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    </array>
</dict>
```

Nothing further needs to be done for this to work — but here's exactly why, so a future change doesn't accidentally break it.

**3.1 — Why the scheme exists at all.** With no APNs entitlement, Firebase can't silently confirm the device is real, so it falls back to a Safari-hosted reCAPTCHA challenge. That challenge runs *outside* the app (in `SFSafariViewController`/`ASWebAuthenticationSession`), so when the user completes it, iOS needs a way to hand control back to PosterNung — that's what a custom URL scheme is for. iOS routes any URL matching a registered scheme to the app that registered it. The actual redirect observed on the wire is `<scheme>://link?deep_link_id=<the posternung-sit.firebaseapp.com/__/auth/callback URL, url-encoded>&eventId=...` — not the simpler `<scheme>://firebaseauth/link?...` shape older docs sometimes show; `deep_link_id` is the payload firebase_auth actually reads.

**3.2 — Why the value must be exactly the bundle ID.** The Firebase iOS SDK builds this redirect URL from `Bundle.main.bundleIdentifier` at runtime, not from anything you configure in Firebase Console. If the scheme registered in Info.plist doesn't match the bundle ID exactly, the redirect has nowhere to land — iOS just fails to open it and the challenge hangs.

**3.3 — Why it's `$(PRODUCT_BUNDLE_IDENTIFIER)`, not a literal string.** This project ships three environments with three different bundle IDs, resolved per Xcode build configuration:

| Flavor | `PRODUCT_BUNDLE_ID_SUFFIX` (`ios/Flutter/*.xcconfig`) | Resolved bundle ID |
|---|---|---|
| sit | `.sit` | `com.frameshine.posternung.sit` |
| uat | `.uat` | `com.frameshine.posternung.uat` |
| production | *(empty)* | `com.frameshine.posternung` |

`project.pbxproj` sets `PRODUCT_BUNDLE_IDENTIFIER = "com.frameshine.posternung$(PRODUCT_BUNDLE_ID_SUFFIX)"` identically across all 9 build configurations, and Info.plist's `CFBundleIdentifier` already resolves through the same variable. Reusing `$(PRODUCT_BUNDLE_IDENTIFIER)` for the URL scheme means it automatically tracks whichever flavor is building — a hardcoded string would only be correct for one of the three.

**3.4 — Why it's a second `<dict>`, not a second scheme in the existing one.** The first `<dict>` in `CFBundleURLTypes` belongs to Google Sign-In (`$(REVERSED_CLIENT_ID)`) and must stay untouched. Each URL type is its own dict by convention — don't merge the two schemes into one array under a single dict.

**3.5 — Why no Swift code is needed.** This project uses Flutter's newer **UIScene** app lifecycle (`UIApplicationSceneManifest` is set in Info.plist, and `ios/Runner/SceneDelegate.swift` is an empty `FlutterSceneDelegate` subclass — there's no custom `application(_:open:options:)` in `AppDelegate.swift`, and none is needed). Under this lifecycle, iOS delivers URL opens to the scene delegate's `scene(_:openURLContexts:)`, not the app delegate's `application(_:open:options:)`. `FlutterSceneDelegate` forwards that event to every registered plugin, and `firebase_auth` (verified against the vendored 6.5.4 pod) conditionally conforms to `FlutterSceneLifeCycleDelegate` and implements `scene:openURLContexts:` by calling `[[FIRAuth auth] canHandleURL:]`. Because `UIApplicationSupportsMultipleScenes` is `false`, Flutter auto-registers the engine for scene events with no extra wiring. **This is why older Firebase Phone Auth guides that tell you to override `application(_:open:options:)` don't apply here** — that advice targets the pre-UIScene template. The one thing that *would* break this: turning on `UIApplicationSupportsMultipleScenes`, which requires manually registering the `FlutterEngine` for scene events (see `FlutterSceneLifeCycleEngineRegistration` in the Flutter SDK headers) — don't flip that on without also doing that registration.

**3.5.1 — The engine ALSO tries to route that same URL, and that's expected.** `firebase_auth`'s `scene:openURLContexts:` handling above is real and does complete the auth — but the Flutter *engine* independently treats every incoming URL as a potential navigation route too, and this app has no route table at all (`MaterialApp` in `lib/main.dart` only sets `home:`). Left at Flutter's default, that shows up as `_WidgetsAppState` logging `Could not find a generator for route RouteSettings("/link?deep_link_id=...&authType=verifyApp&...", null)` every time the reCAPTCHA challenge completes. **This is not a failure** — it fires after the challenge already passed, auth still completes normally, and it's purely `FlutterError.reportError` noise. `ios/Runner/Info.plist` sets `FlutterDeepLinkingEnabled` to `false` specifically to suppress this second path, without touching the scene-delegate path `firebase_auth` actually uses. If you ever add real deep/universal links, that key needs to come back out together with an actual route table (`onGenerateRoute` or `MaterialApp.router`).

**3.6 — How to verify the scheme actually resolved.** The *source* Info.plist still shows the unresolved `$(PRODUCT_BUNDLE_IDENTIFIER)` placeholder — you have to inspect a **built** app to see the real value:

```bash
flutter build ios --flavor sit --no-codesign --debug
plutil -p "$(find build/ios -name Runner.app -maxdepth 3 | head -1)/Info.plist" \
  | grep -A4 CFBundleURLSchemes
```

Expect to see both `com.googleusercontent.apps.…` (Google) and `com.frameshine.posternung.sit` (this fallback) in the output. Swap `--flavor sit` for `uat`/`production` and expect `com.frameshine.posternung.uat` / `com.frameshine.posternung` respectively.

**3.7 — Pitfalls.**
- Don't hardcode the production bundle ID here "to keep it simple" — it silently breaks the fallback on sit and uat, which is easy to miss because the app still builds and only phone auth on those two flavors quietly hangs at the reCAPTCHA step.
- Don't remove the Google `<dict>` when adding or editing this one.
- A URL scheme is a Info.plist-only registration, not a capability — it needs no Apple Developer Portal step and doesn't touch code signing/provisioning, unlike the APNs upgrade path below.

**To upgrade to silent APNs verification later** (skips the reCAPTCHA challenge entirely):
1. In Xcode, select the Runner target → **Signing & Capabilities** → **+ Capability** → **Push Notifications**, then add **Background Modes** → check **Remote notifications**. This generates `ios/Runner/Runner.entitlements` and wires `CODE_SIGN_ENTITLEMENTS` automatically (same mechanism noted for Sign in with Apple in `docs/social-login-setup.md`).
2. Create an APNs authentication key in the [Apple Developer portal](https://developer.apple.com/account/resources) (Certificates, Identifiers & Profiles → Keys) and upload it to Firebase Console → Project settings → Cloud Messaging → Apple app configuration.
3. Requires a paid Apple Developer Program membership (same constraint as Sign in with Apple) — a free/Personal Team can't provision the Push Notifications capability.

## 4. Test phone numbers (recommended for development)

Firebase Console → **Authentication → Sign-in method → Phone → Phone numbers for testing**. Add a number + a fixed 6-digit code (e.g. `+66812345678` → `123456`) so you can develop and run widget/manual tests without consuming real SMS quota or needing a physical device with a live number.

## 5. Web — Authorized domains

Firebase Console → **Authentication → Settings → Authorized domains**. Confirm `localhost` (dev) and the production web host (if/when the app ships on web) are both listed — the reCAPTCHA verification step Firebase Web uses for phone auth needs the calling origin to be authorized.

---

## Follow-ups (documented, not yet implemented)

Worth doing before phone auth is exposed to real, untrusted users at any scale — none of this blocks the console setup above from working today:

- **Firebase App Check** — attests that SMS requests come from the genuine app binary, not a scripted client. The strongest defense against SMS-pumping fraud beyond the region policy in step 1.
- **A client-side resend cap** — `OtpVerificationScreen`'s resend button has a 30s countdown but no cap on how many times it can be tapped in a row. A small in-memory counter (e.g. max 3 resends per OTP session) is a cheap first line of defense before App Check is in place.
- **Treat `web-context-cancelled` as a silent cancel**, the way `AuthViewModel._runSocial` already swallows `AuthCancelledException` for Google (the only social sign-in method left — see `docs/social-login-setup.md`'s banner on Apple's removal, ADR-0021 D4). Right now dismissing the reCAPTCHA Safari sheet without completing it surfaces as a visible error banner instead of just returning the user to where they were.

## Verify

Once steps 1–2 (and optionally 4) are done, run on a device/emulator and submit a phone number from the login screen's phone tab. A successful send navigates to the OTP screen; entering the correct code (or the fixed test code from step 4) exchanges the resulting Firebase ID token at `POST /api/v1/auth/firebase`, stores the returned JWT session, and flows through `sessionProvider` → `AuthGate` to the home screen — same as email/password and Google. Tap **ส่งรหัสอีกครั้ง** (resend) after the 30s countdown and confirm a *second* real SMS actually arrives — this requires `forceResendingToken` to be threaded through correctly (see below); without it, Firebase silently sends nothing on resend.

## How the code is wired (reference)

- `lib/core/utils/thai_phone_number.dart` — `thaiMobileToE164`, converts what the user typed (with or without a leading `0`) into the E.164 form Firebase requires.
- `lib/features/auth/data/datasources/phone_sign_in_data_source.dart` — `verifyPhoneNumber` → `SmsCodeSent(verificationId, resendToken: …)` / `PhoneAutoVerified(idToken)`; `confirmCode` → Firebase ID token. `sendCode` takes an optional `resendToken`, forwarded to `verifyPhoneNumber`'s `forceResendingToken` — Firebase's own docs: *"No duplicated SMS will be sent out unless a `forceResendingToken` is provided."*
- `lib/features/auth/presentation/providers/backend_session_provider.dart` — `sendPhoneCode`/`confirmPhoneCode` on `BackendSessionNotifier`, both funnel into the same `_exchangeAndPublish` helper Google and email/password already use.
- `lib/features/auth/presentation/providers/auth_providers.dart` — `AuthViewModel.sendPhoneCode`/`confirmPhoneCode`.
- `lib/features/auth/presentation/screens/login_screen.dart` — phone tab's submit calls `sendPhoneCode`, pushes the OTP screen on `SmsCodeSent`.
- `lib/features/auth/presentation/screens/otp_verification_screen.dart` — code entry, resend (holds and refreshes `resendToken` locally, same pattern as `verificationId`), and the `confirmPhoneCode` call.
- `lib/features/auth/presentation/auth_error_display.dart` — maps Firebase phone-auth error codes (`invalid-phone-number`, `invalid-verification-code`, `quota-exceeded`, …) to Thai messages, same mechanism as the email/password codes.
