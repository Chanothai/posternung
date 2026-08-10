# Social Login Setup (Google & Apple)

🔴 **Apple sign-in's Dart code was deleted end-to-end under ADR-0021 D4 (2026-08-10)** — not hidden behind a flag any more. The rest of this document (steps 1, 4, 5's Apple parts) is kept as forward reference for *when* it comes back, not as a description of code that exists today. Unlock condition: `apple.com` added to the backend's `_SIGN_IN_PROVIDER_MAP` with a corresponding `oauth_identities` enum value and an ADR that says so — start at `posternung-backend`'s ADR-0004 §1, not at this app. See `lib/features/auth/CLAUDE.md` for the reasoning.

The Dart code for Google sign-in is complete and merged, but it **will not work at runtime until the console/native setup below is done** — none of it can be committed to the repo because it depends on account-specific values and provider enablement. Follow these steps in order. The app still builds and CI stays green without them; sign-in just fails at runtime until they're finished.

Bundle ID / package name: `com.frameshine.posternung`.

> **Google is Firebase-mediated, then exchanged for a backend session.** Google Sign-In yields a Google `id_token` → the app signs into Firebase with it (`signInWithCredential`) → sends the resulting **Firebase ID token** to `posternung-backend`'s `POST /api/v1/auth/google` (the backend runs `verify_firebase_token`, so a raw Google token gets a 401 `OAUTH_TOKEN_INVALID`). The returned `{access_token, refresh_token}` JWT session is stored in `flutter_secure_storage`. Consequences: (a) Google **must** be enabled as a Firebase sign-in provider (the app needs Firebase to mint the token — step 1); (b) a Google login establishes *both* a Firebase session and the backend session, and `sessionProvider` gates on either; (c) the Android `GOOGLE_SERVER_CLIENT_ID` (step 5) still applies — it's what makes the SDK return a usable `id_token`; (d) the backend must be reachable, i.e. `--dart-define=API_BASE_URL=...` (see `docs/environments-setup.md`). Firebase backs email/password + Apple as before.

> **Status:** the package/bundle identifier was renamed from `com.example.posternung` to `com.frameshine.posternung`. New Android + iOS apps have been registered under the new identifier in the `posternung` Firebase project and `google-services.json` / `GoogleService-Info.plist` / `lib/firebase_options.dart` are regenerated and committed (steps 2 & 3 below are done). The **old** `com.example.posternung` app entries still exist in the Firebase project (Firebase doesn't let you rename an app's package/bundle ID) — they're now unused; delete them from Project settings → Your apps whenever convenient, no rush. Steps 1 and 2 are done; step 4 (Apple Developer portal) and step 5 (Android SHA fingerprints + web client ID) still require manual console/portal access.
>
> **iOS Sign in with Apple is currently disabled at the native level, and the Dart code is gone (ADR-0021 D4).** A free/Personal Apple ID team cannot generate a provisioning profile for an app with the Sign in with Apple capability — Xcode blocks it outright. The `CODE_SIGN_ENTITLEMENTS` build setting and `ios/Runner/Runner.entitlements` were removed from the Runner target so the app can build and run on a physical device under a Personal Team. 🔴 There is no longer an `appleSignInEnabled`/`showAppleButton` flag to flip — the usecase, repository/datasource methods, provider, and the button + handler in `login_screen.dart` were deleted, not hidden, because the backend rejects `apple.com` with `401 OAUTH_TOKEN_INVALID` unconditionally (a button that can only ever fail is worse than no button). To restore Apple sign-in: (1) the Apple Developer / Xcode side below, **and** (2) backend support first — see the banner at the top of this file.

---

## 1. ~~Firebase Console — enable providers~~ — done

Email/Password, Google, and Apple are all enabled in [Firebase Console](https://console.firebase.google.com/project/posternung) → **Authentication → Sign-in method**. Apple sign-in still needs the Services ID/key from step 4 entered into the provider config before it can verify tokens end-to-end.

## 2. ~~Regenerate the Firebase config files~~ — done

`google-services.json`, `GoogleService-Info.plist`, and `lib/firebase_options.dart` are already regenerated and committed for the `com.frameshine.posternung` apps (via `flutterfire configure --project=posternung`).

## 3. ~~iOS — Google URL scheme~~ — done

`ios/Runner/Info.plist` already has the `CFBundleURLTypes` entry wired with the real `REVERSED_CLIENT_ID`.

(The "Sign in with Apple" entitlement has been removed from the Runner target — see the status note above. No further Info.plist change is needed for Google.)

## 4. Apple Developer — Sign in with Apple (blocked until paid membership)

Requires a paid [Apple Developer Program](https://developer.apple.com/programs/) membership — a free/Personal Team cannot provision an app with this capability. Once enrolled:

1. In Xcode, select the Runner target → **Signing & Capabilities** → **+ Capability** → **Sign in with Apple**. This regenerates `ios/Runner/Runner.entitlements` and re-wires `CODE_SIGN_ENTITLEMENTS` in the project automatically.
2. In the [Apple Developer portal](https://developer.apple.com/account/resources): **Certificates, Identifiers & Profiles → Identifiers →** your App ID (`com.frameshine.posternung`) → enable the **Sign in with Apple** capability → Save.
3. Create a **Services ID** and a **Sign in with Apple key**, then enter them in the Firebase Console Apple provider config (Services ID, Team ID, Key ID, private key) — required for Firebase to verify Apple tokens.

## 5. Android — SHA fingerprints + web client ID

1. Register your app's SHA-1 **and** SHA-256 in the Firebase Console (Project settings → Your apps → Android → Add fingerprint). Get them with:
   ```bash
   cd android && ./gradlew signingReport
   ```
   Re-run `flutterfire configure` (or re-download `google-services.json`) afterward.
2. Android only returns an `idToken` when the app passes the project's **web** OAuth client ID as `serverClientId`. Find it in the Google Cloud console (APIs & Services → Credentials → "Web client (auto created by Google Service)") and pass it at build/run time:
   ```bash
   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
   ```
   (Wire the same `--dart-define` into your release build config / CI when shipping.)

---

## Verify

Once all steps are done, run on a real device or simulator (with `--dart-define=API_BASE_URL=...` and `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`) and tap **เข้าสู่ระบบด้วย Google**. A successful sign-in exchanges the Firebase ID token at `POST /api/v1/auth/firebase` (`/auth/google` is deprecated), stores the returned JWT session, and flows through `sessionProvider` → `AuthGate` to the home screen. (There is no Apple button any more — see the banner at the top of this file.)

## How the code is wired (reference)

- `lib/features/auth/data/datasources/google_sign_in_data_source.dart` — Google SDK → Firebase `signInWithCredential` → Firebase ID token (sent to the backend).
- `lib/features/auth/data/datasources/backend_auth_data_source.dart` — `POST /auth/firebase`, `GET /auth/me`, `POST /auth/refresh` via Dio.
- `lib/features/auth/data/datasources/auth_remote_data_source.dart` — Firebase sign-out + the raw auth-state stream only (ADR-0021 D4 removed the Apple credential flow that used to live here).
- `lib/features/auth/presentation/providers/backend_session_provider.dart` — `BackendSessionNotifier`: Google login, token storage, `/auth/me` restore-on-startup, sign-out.
- `lib/features/auth/presentation/providers/session_provider.dart` — a thin alias over the backend JWT session (ADR-0021 D1); `AuthGate` watches this.
- `lib/features/auth/presentation/providers/auth_providers.dart` — `AuthViewModel.signInWithGoogle()` (→ backend).
- `lib/features/auth/presentation/screens/login_screen.dart` — the Google button (disabled on web with a "mobile only" notice).
- `lib/core/network/token_storage.dart` — `TokenStorage` over `flutter_secure_storage`.
