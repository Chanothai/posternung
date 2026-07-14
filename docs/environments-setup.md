# Build Environments Setup (SIT / UAT / Production)

The app builds as three environments — **SIT**, **UAT**, **Production** — installable side by side on the same device (distinct bundle ID / app name / icon each), backed by a single shared Firebase project (`posternung`). The code-side scaffolding (Android flavors, iOS xcconfigs, the Dart `Environment` abstraction) is already committed. **The steps below are manual** — they need your Firebase login and/or Xcode's GUI, so they can't be automated here.

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

## 4. iOS — finish the Xcode-side flavor wiring (GUI only)

The xcconfig files, `Info.plist` variable, and `PRODUCT_BUNDLE_IDENTIFIER`/`ASSETCATALOG_COMPILER_APPICON_NAME` indirection are already in place (`ios/Flutter/{Sit,Uat,Production}.xcconfig` + 9 combinator files). What's left needs Xcode's GUI, not a text editor — duplicating build configurations and creating schemes by hand in the `.pbxproj`/`.xcscheme` XML is high-risk (a single mismatched UUID or missed `buildConfigurationList` entry can produce a project that fails to open or silently drops a flavor):

1. Open `ios/Runner.xcodeproj` in Xcode.
2. Select the **Runner** project (top of the navigator) → **Info** tab → **Configurations**. Duplicate each of `Debug`, `Release`, `Profile` twice, naming the 6 new ones `Debug-sit`, `Release-sit`, `Profile-sit`, `Debug-uat`, `Release-uat`, `Profile-uat`. Rename the original three to `Debug-production`, `Release-production`, `Profile-production`.
3. For each of the 9 configs, on the **Runner** target, set its **Based on Configuration File** (under Build Settings, or via the Info tab's per-target xcconfig picker) to the matching file in `ios/Flutter/`: `Debug-sit.xcconfig`, `Release-sit.xcconfig`, etc.
4. **Product → Scheme → Manage Schemes** → duplicate the existing `Runner` scheme twice, naming the copies `sit` and `uat`; rename the original to `production`. For each scheme, edit its Test/Run/Profile/Archive/Analyze actions to use the matching `-sit`/`-uat`/`-production` build configuration.
5. Build each scheme once to confirm it compiles.

## 5. Design and export per-environment app icons

Placeholder locations already exist — replace with real artwork:

- Android: `android/app/src/sit/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`, same under `src/uat/res/`.
- iOS: `ios/Runner/Assets.xcassets/AppIcon-Sit.appiconset/`, `AppIcon-Uat.appiconset/` — each already has a `Contents.json` matching the production set's sizes; add the PNG files.

Until these exist, SIT/UAT builds simply show the default (production) icon.

## Verifying it's all wired up

- `flutter run --flavor sit -t lib/main.dart` (same for `uat`/`production`) — after steps 1–3, this should launch with the right Firebase project data and app identity.
- On iOS, select the `sit`/`uat`/`production` scheme in Xcode and run — after step 4, GoogleService-Info.plist selection and bundle ID/icon should follow automatically.
- All three environments should be able to coexist installed on one device/simulator at once.
