# Social Login Setup (Google & Apple)

The Dart code for Google and Apple sign-in is complete and merged, but it **will not work at runtime until the console/native setup below is done** — none of it can be committed to the repo because it depends on account-specific values and provider enablement. Follow these steps in order. The app still builds and CI stays green without them; sign-in just fails at runtime until they're finished.

Bundle ID / package name: `com.example.posternung`.

---

## 1. Firebase Console — enable providers

[Firebase Console](https://console.firebase.google.com/project/posternung) → **Authentication → Sign-in method**:

1. **Google** → Enable → set a support email → Save.
2. **Apple** → Enable → Save. (Full functionality also needs the Apple Developer setup in step 4.)

## 2. Regenerate the Firebase config files

Enabling Google creates an OAuth client. Pull the updated config (regenerates `google-services.json`, `GoogleService-Info.plist`, and `lib/firebase_options.dart` — now including the iOS `REVERSED_CLIENT_ID`):

```bash
flutterfire configure --project=posternung
```

Commit the regenerated files.

## 3. iOS — Google URL scheme

Open the refreshed `ios/Runner/GoogleService-Info.plist`, copy the `REVERSED_CLIENT_ID` value, and add it as a URL scheme in `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>REVERSED_CLIENT_ID_GOES_HERE</string>
    </array>
  </dict>
</array>
```

(The "Sign in with Apple" entitlement — `ios/Runner/Runner.entitlements`, wired via `CODE_SIGN_ENTITLEMENTS` — is already committed. No Info.plist change is needed for Apple.)

## 4. Apple Developer — Sign in with Apple

In the [Apple Developer portal](https://developer.apple.com/account/resources):

1. **Certificates, Identifiers & Profiles → Identifiers →** your App ID (`com.example.posternung`) → enable the **Sign in with Apple** capability → Save.
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
