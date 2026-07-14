# Social Login Setup (Google & Apple)

The Dart code for Google and Apple sign-in is complete and merged, but it **will not work at runtime until the console/native setup below is done** — none of it can be committed to the repo because it depends on account-specific values and provider enablement. Follow these steps in order. The app still builds and CI stays green without them; sign-in just fails at runtime until they're finished.

Bundle ID / package name: `com.frameshine.posternung`.

> **Status:** the package/bundle identifier was renamed from `com.example.posternung` to `com.frameshine.posternung`. New Android + iOS apps have been registered under the new identifier in the `posternung` Firebase project and `google-services.json` / `GoogleService-Info.plist` / `lib/firebase_options.dart` are regenerated and committed (steps 2 & 3 below are done). The **old** `com.example.posternung` app entries still exist in the Firebase project (Firebase doesn't let you rename an app's package/bundle ID) — they're now unused; delete them from Project settings → Your apps whenever convenient, no rush. Steps 1 and 2 are done; step 4 (Apple Developer portal) and step 5 (Android SHA fingerprints + web client ID) still require manual console/portal access.

---

## 1. ~~Firebase Console — enable providers~~ — done

Email/Password, Google, and Apple are all enabled in [Firebase Console](https://console.firebase.google.com/project/posternung) → **Authentication → Sign-in method**. Apple sign-in still needs the Services ID/key from step 4 entered into the provider config before it can verify tokens end-to-end.

## 2. ~~Regenerate the Firebase config files~~ — done

`google-services.json`, `GoogleService-Info.plist`, and `lib/firebase_options.dart` are already regenerated and committed for the `com.frameshine.posternung` apps (via `flutterfire configure --project=posternung`).

## 3. ~~iOS — Google URL scheme~~ — done

`ios/Runner/Info.plist` already has the `CFBundleURLTypes` entry wired with the real `REVERSED_CLIENT_ID`.

(The "Sign in with Apple" entitlement — `ios/Runner/Runner.entitlements`, wired via `CODE_SIGN_ENTITLEMENTS` — is already committed. No further Info.plist change is needed for Apple.)

## 4. Apple Developer — Sign in with Apple

In the [Apple Developer portal](https://developer.apple.com/account/resources):

1. **Certificates, Identifiers & Profiles → Identifiers →** your App ID (`com.frameshine.posternung`) → enable the **Sign in with Apple** capability → Save.
2. Create a **Services ID** and a **Sign in with Apple key**, then enter them in the Firebase Console Apple provider config (Services ID, Team ID, Key ID, private key) — required for Firebase to verify Apple tokens.
3. In Xcode (or already done via the committed entitlement), confirm the **Sign in with Apple** capability is present on the Runner target.

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

Once all steps are done, run on a real device or simulator and tap **เข้าสู่ระบบด้วย Google** / **เข้าสู่ระบบด้วย Apple** (Apple button shows on iOS only). A successful sign-in flows through `authStateChangesProvider` → `AuthGate` and lands on the home screen, exactly like email/password.

## How the code is wired (reference)

- `lib/features/auth/data/datasources/auth_remote_data_source.dart` — the google_sign_in / sign_in_with_apple → Firebase credential flow.
- `lib/features/auth/data/repositories/auth_repository_impl.dart` — maps SDK errors to `AuthException`, and user cancellation to `AuthCancelledException` (shown silently).
- `lib/features/auth/presentation/providers/auth_providers.dart` — `AuthViewModel.signInWithGoogle()` / `signInWithApple()`.
- `lib/features/auth/presentation/screens/login_screen.dart` — the buttons (Apple gated to iOS; both disabled on web with a "mobile only" notice).
