# Build Environments Setup (SIT / UAT / Production)

The app builds as three environments — **SIT**, **UAT**, **Production** — installable side by side on the same device (distinct bundle ID / app name / icon each). All the code-side scaffolding is committed, **including** the Xcode build configurations and `sit`/`uat`/`production` schemes — `flutter run --flavor sit` (or the matching Xcode scheme) works today. **The steps below are the remaining manual ones** — they need your Firebase login, so they can't be automated here.

| Environment | Application ID / Bundle ID | Firebase project | Firebase app registration |
|---|---|---|---|
| SIT | `com.frameshine.posternung.sit` | `posternung-sit` (**separate project**) | done |
| UAT | `com.frameshine.posternung.uat` | `posternung` | done |
| Production | `com.frameshine.posternung` | `posternung` | already exists, untouched |

**SIT is its own Firebase project (`posternung-sit`), not an app inside `posternung`** — a deliberate split from UAT/production so SIT can be reconfigured/reset freely without touching shared data. Keep that in mind when following console steps below written for the shared `posternung` project: for SIT, do the equivalent step inside `posternung-sit` instead.

> ⚠️ **If you ever re-point SIT (or any environment) at a different/new Firebase project, `lib/firebase_options_<env>.dart` MUST be regenerated in the same change** (step 3 below) — it is not optional or "nice to keep in sync later." Native iOS/Android auto-configure the default Firebase app from the bundled `GoogleService-Info.plist`/`google-services.json` *before* Dart runs; `Firebase.initializeApp()` then compares its own hardcoded options against that already-configured app and throws `FirebaseException ([core/duplicate-app] ...)` the moment `apiKey`/`projectId`/`storageBucket` disagree. This exact mismatch happened once already (SIT's native configs were updated to `posternung-sit`, but `firebase_options_sit.dart` was left pointing at the old `posternung` values) — the error message gives no hint that it's a config-sync issue, so it's worth remembering this class of bug exists.
>
> **Three files derive from a project's config, and re-pointing an environment must update all three** — each fails differently and none of them fails loudly:
> 1. `android/app/src/<flavor>/google-services.json` + `ios/Runner/Firebase/<flavor>/GoogleService-Info.plist` — the native configs.
> 2. `lib/firebase_options_<env>.dart` — miss it and you get the `[core/duplicate-app]` crash above. Note `flutterfire configure --platforms=android,ios` leaves the file's **`web` block untouched**, so it silently keeps the previous project's values.
> 3. `ios/Flutter/<Env>.xcconfig`'s `REVERSED_CLIENT_ID` — must equal the `REVERSED_CLIENT_ID` in *that flavor's* plist. It feeds the `CFBundleURLSchemes` entry in `Info.plist`, which is what lets Google Sign-In's OAuth callback route back into the app. **Miss it and there is no error at all** — the sign-in sheet opens, the user consents, and the redirect goes nowhere. (SIT hit exactly this after moving to `posternung-sit`.) Verify with:
>    ```bash
>    plutil -extract REVERSED_CLIENT_ID raw ios/Runner/Firebase/sit/GoogleService-Info.plist
>    grep REVERSED_CLIENT_ID ios/Flutter/Sit.xcconfig
>    ```

> **Steps 1–3 are all done for every environment** — kept below as the reference procedure for adding a 4th environment or rotating an existing one, not as outstanding work.

## 1. Register apps in Firebase Console — done

All three environments' Android + iOS apps are registered: SIT in the separate [`posternung-sit`](https://console.firebase.google.com/project/posternung-sit) project, UAT and production in [`posternung`](https://console.firebase.google.com/project/posternung). To add another, it's Project settings → **Add app**, using the Application ID / Bundle ID from the table above.

## 2. Download and place the config files — done

Each flavor's config is in place: `android/app/src/{sit,uat,production}/google-services.json` and `ios/Runner/Firebase/{sit,uat,production}/GoogleService-Info.plist`. For a new environment, download them from Project settings → Your apps and drop them at the same per-flavor paths.

   (Note on the shared `posternung` project: its `google-services.json` download contains a client entry for *every* registered package, so the UAT and production copies are byte-identical — that's expected, Gradle picks the entry matching the flavor's application ID. SIT's differs because it comes from a different project entirely.)

   (Production's copy lives at `ios/Runner/Firebase/production/GoogleService-Info.plist`, SIT's at `ios/Runner/Firebase/sit/GoogleService-Info.plist` — leave both as is unless you're intentionally rotating them.) These per-flavor files are the source of truth; `ios/Runner/GoogleService-Info.plist` itself is gitignored and regenerated at build time by a Run Script build phase that copies the right one in based on the active build configuration. Similarly there is no shared `android/app/google-services.json` — each flavor's copy lives under `android/app/src/<flavor>/`; `flutterfire configure`/the Firebase Console download flow sometimes writes a stray one at `android/app/google-services.json` by default — delete it if that happens, since it isn't wired into any flavor's build.

## 3. Run `flutterfire configure` — done for all three

All three `lib/firebase_options_<env>.dart` files hold real values and match their bundled native configs. The commands that produced them, for reference when rotating or adding an environment — SIT, against the separate `posternung-sit` project:

```bash
flutterfire configure --project=posternung-sit \
  --out=lib/firebase_options_sit.dart \
  --platforms=android,ios \
  --android-package-name=com.frameshine.posternung.sit \
  --ios-bundle-id=com.frameshine.posternung.sit
```

(`--platforms=android,ios` deliberately excludes `web` — SIT has no registered web app in `posternung-sit`, and it isn't needed since SIT is a mobile-only environment in practice. **Known consequence:** because that run didn't touch the `web` block, `firebase_options_sit.dart`'s `web` entry is stale — it still points at the old shared `posternung` project. On mobile this is unreachable dead config, but `flutter run -d chrome` resolves to SIT by default and would silently talk to `posternung` instead of `posternung-sit`. Pass `--dart-define=ENVIRONMENT=production` when running on web, or register a SIT web app and re-run with `--platforms=android,ios,web` if SIT-on-web is ever needed.) And UAT, inside the shared `posternung` project:

```bash
flutterfire configure --project=posternung \
  --out=lib/firebase_options_uat.dart \
  --android-package-name=com.frameshine.posternung.uat \
  --ios-bundle-id=com.frameshine.posternung.uat
```

Each run overwrites the corresponding file. **Note:** `flutterfire configure` always names the generated class `DefaultFirebaseOptions` regardless of the `--out` filename — that's expected, `lib/core/config/firebase_options_selector.dart` already imports each file with an `as` prefix to avoid the collision. Don't rename the generated class; it'll be overwritten next time the CLI runs.

`firebase.json` will also be rewritten by these runs — commit whatever the CLI produces, don't hand-edit it.

## 4. iOS build configurations and schemes — already done

`ios/Runner.xcodeproj` now has 9 build configurations (`Debug-sit`, `Release-sit`, `Profile-sit`, `Debug-uat`, `Release-uat`, `Profile-uat`, `Debug-production`, `Release-production`, `Profile-production`) and 3 schemes (`sit`, `uat`, `production`), each wired to the matching `ios/Flutter/*.xcconfig` file. `flutter build ios --flavor sit` / `--flavor uat` / `--flavor production` all work today — verified end to end, including the Run Script phase correctly selecting the per-environment `GoogleService-Info.plist`.

If you ever need to touch these by hand in Xcode (e.g. adding a 4th environment), open `ios/Runner.xcodeproj` → select the **Runner** project → **Info** tab → **Configurations** to see the 9 configs, and **Product → Scheme → Manage Schemes** for the 3 schemes — but for the existing three, nothing further is needed here.

## 5. Design and export per-environment app icons

Placeholder locations already exist — replace with real artwork:

- Android: `android/app/src/sit/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`, same under `src/uat/res/`.
- iOS: `ios/Runner/Assets.xcassets/AppIcon-Sit.appiconset/`, `AppIcon-Uat.appiconset/` — each already has a `Contents.json` matching the production set's sizes; add the PNG files.

Until these exist, SIT/UAT builds simply show the default (production) icon.

## 6. Backend API base URL

`lib/core/config/api_base_url_resolver.dart`'s `apiBaseUrlFor(Environment)` holds the base URL per environment. **Production** resolves to the stable domain `https://api.posternung.com` by default — no override needed. **SIT** defaults to `http://172.20.10.12:8000` — a developer's LAN IP running `posternung-backend` locally (the `posternung-sit-app` container publishing port 8000), since SIT has no deployed backend of its own. **UAT** has no backend deployed yet (empty default); wire it here once it does.

**The SIT default is one developer's machine, not a shared value** — a real device can't use `127.0.0.1` (that resolves to the device itself, not your Mac), and the IP changes with the network. Override it for your own setup instead of editing the hardcoded default:

```bash
flutter run --flavor sit --dart-define=API_BASE_URL=http://<your-lan-ip>:8000
```

Different target, different address: Android Emulator → `10.0.2.2`, iOS Simulator → `127.0.0.1` (both reach the host machine directly, no LAN IP needed). Find your LAN IP with `ipconfig getifaddr en0` (Wi-Fi) on macOS.

Plain `http://` needs platform opt-in, already wired for `debug`/`profile` builds only (never `release`, so a shipped build can't be pointed at cleartext by mistake): Android's `usesCleartextTraffic` in `android/app/src/{debug,profile}/AndroidManifest.xml`, and iOS's `NSAllowsLocalNetworking` ATS exception in `ios/Runner/Info.plist` (shared across all flavors since Info.plist isn't per-flavor — harmless on uat/production since neither talks to a local backend).

Also note: **`apiBaseUrlFor` must never include `/api/v1`** — `BackendAuthDataSource` already prefixes every call with it; a base URL ending in `/api/v1` doubles the segment and 404s every request.

For ad-hoc testing (a different local backend or a `cloudflared` tunnel), or to exercise UAT before it deploys, override at build/run time the same way:

```bash
flutter run --flavor production --dart-define=API_BASE_URL=https://your-tunnel-url.trycloudflare.com
```

## Verifying it's all wired up

- `flutter run --flavor sit -t lib/main.dart` (same for `uat`/`production`) — builds and launches today. **All three environments are fully configured now** (no `UnimplementedError` placeholders remain in any `lib/firebase_options_<env>.dart`), and each flavor's Dart-side options were verified field-by-field against its bundled native config — `apiKey`/`appId`/`projectId`/`storageBucket` match on both platforms for all three.
- On iOS, selecting the `sit`/`uat`/`production` scheme in Xcode and running picks up the right bundle ID, display name, and `GoogleService-Info.plist` automatically — confirmed via `flutter build ios --flavor <env> --no-codesign` for all three, and via `flutter install --flavor sit` onto a physical iPhone.
- All three environments install side by side on one device/simulator (distinct bundle IDs) once a real Firebase app exists for UAT.
- If `Firebase.initializeApp()` throws `FirebaseException ([core/duplicate-app] A Firebase App named "[DEFAULT]" already exists)` on a flavor that should be fully configured, that's the config-mismatch class of bug flagged above — go regenerate that flavor's `firebase_options_<env>.dart` (step 3), don't look for a second `initializeApp()` call (there is only ever one, in `lib/main.dart`).

### VS Code

A `.vscode/launch.json` with `posternung (sit)` / `(uat)` / `(production)` run configurations is already set up locally (gitignored). Pick one from the **Run and Debug** panel dropdown, or from the terminal:

```bash
flutter run --flavor sit -t lib/main.dart
```
