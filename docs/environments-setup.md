# Build Environments Setup (SIT / UAT / Production)

The app builds as three environments — **SIT**, **UAT**, **Production** — installable side by side on the same device (distinct bundle ID / app name / icon each), backed by a single shared Firebase project (`posternung`). All the code-side scaffolding is committed, **including** the Xcode build configurations and `sit`/`uat`/`production` schemes — `flutter run --flavor sit` (or the matching Xcode scheme) works today. **The steps below are the remaining manual ones** — they need your Firebase login, so they can't be automated here.

| Environment | Application ID / Bundle ID | Firebase app registration |
|---|---|---|
| SIT | `com.frameshine.posternung.sit` | new — you register this |
| UAT | `com.frameshine.posternung.uat` | new — you register this |
| Production | `com.frameshine.posternung` | already exists, untouched |

## 1. Register SIT and UAT apps in Firebase Console

In the [`posternung` Firebase project](https://console.firebase.google.com/project/posternung) → Project settings → **Add app**:

1. Android, twice: package names `com.frameshine.posternung.sit` and `com.frameshine.posternung.uat`.
2. iOS, twice: bundle IDs `com.frameshine.posternung.sit` and `com.frameshine.posternung.uat`.

## 2. Download and place the config files

1. Download the regenerated `google-services.json` (Project settings → Your apps → Android → any app → `google-services.json`) — it will now contain client entries for all 4 registered Android apps. Overwrite `android/app/google-services.json`.
2. Download each new iOS app's `GoogleService-Info.plist` and place it at:
   - `ios/Runner/Firebase/sit/GoogleService-Info.plist`
   - `ios/Runner/Firebase/uat/GoogleService-Info.plist`

   (Production's copy already lives at `ios/Runner/Firebase/production/GoogleService-Info.plist` — leave it as is.) These 3 files are the source of truth; `ios/Runner/GoogleService-Info.plist` itself is gitignored and regenerated at build time by a Run Script build phase that copies the right one in based on the active build configuration.

## 3. Run `flutterfire configure` for SIT and UAT

Production's `lib/firebase_options_production.dart` already has the right values — no need to touch it. For the two new environments:

```bash
flutterfire configure --project=posternung \
  --out=lib/firebase_options_sit.dart \
  --android-package-name=com.frameshine.posternung.sit \
  --ios-bundle-id=com.frameshine.posternung.sit

flutterfire configure --project=posternung \
  --out=lib/firebase_options_uat.dart \
  --android-package-name=com.frameshine.posternung.uat \
  --ios-bundle-id=com.frameshine.posternung.uat
```

Each run overwrites the corresponding placeholder file (which currently just throws `UnimplementedError`). **Note:** `flutterfire configure` always names the generated class `DefaultFirebaseOptions` regardless of the `--out` filename — that's expected, `lib/core/config/firebase_options_selector.dart` already imports each file with an `as` prefix to avoid the collision. Don't rename the generated class; it'll be overwritten next time the CLI runs.

`firebase.json` will also be rewritten by these runs — commit whatever the CLI produces, don't hand-edit it.

## 4. iOS build configurations and schemes — already done

`ios/Runner.xcodeproj` now has 9 build configurations (`Debug-sit`, `Release-sit`, `Profile-sit`, `Debug-uat`, `Release-uat`, `Profile-uat`, `Debug-production`, `Release-production`, `Profile-production`) and 3 schemes (`sit`, `uat`, `production`), each wired to the matching `ios/Flutter/*.xcconfig` file. `flutter build ios --flavor sit` / `--flavor uat` / `--flavor production` all work today — verified end to end, including the Run Script phase correctly selecting the per-environment `GoogleService-Info.plist`.

If you ever need to touch these by hand in Xcode (e.g. adding a 4th environment), open `ios/Runner.xcodeproj` → select the **Runner** project → **Info** tab → **Configurations** to see the 9 configs, and **Product → Scheme → Manage Schemes** for the 3 schemes — but for the existing three, nothing further is needed here.

## 5. Design and export per-environment app icons

Placeholder locations already exist — replace with real artwork:

- Android: `android/app/src/sit/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`, same under `src/uat/res/`.
- iOS: `ios/Runner/Assets.xcassets/AppIcon-Sit.appiconset/`, `AppIcon-Uat.appiconset/` — each already has a `Contents.json` matching the production set's sizes; add the PNG files.

Until these exist, SIT/UAT builds simply show the default (production) icon.

## Verifying it's all wired up

- `flutter run --flavor sit -t lib/main.dart` (same for `uat`/`production`) — builds and launches today. SIT/UAT will crash immediately on `Firebase.initializeApp()` (an intentional `UnimplementedError`) until steps 1–3 above are done; production runs fully end to end already.
- On iOS, selecting the `sit`/`uat`/`production` scheme in Xcode and running picks up the right bundle ID, display name, and `GoogleService-Info.plist` automatically — confirmed via `flutter build ios --flavor <env> --no-codesign` for all three.
- All three environments install side by side on one device/simulator (distinct bundle IDs) once real Firebase apps exist for SIT/UAT.

### VS Code

A `.vscode/launch.json` with `posternung (sit)` / `(uat)` / `(production)` run configurations is already set up locally (gitignored). Pick one from the **Run and Debug** panel dropdown, or from the terminal:

```bash
flutter run --flavor sit -t lib/main.dart
```
