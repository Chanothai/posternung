# lib/features/profile/

SCR-07 B7 — the profile tab of `core/widgets/app_bottom_nav_bar.dart`. Shows
the signed-in identity and the one action this round has: sign out, behind a
confirm dialog.

```
presentation/
  screens/  # ProfileScreen — the only file in this feature
```

## Things worth knowing before touching this feature

- **No `data/`/`domain/` folder, and don't add one.** `ProfileScreen` reads
  `sessionProvider` (published by `features/auth/`) and calls
  `authViewModelProvider.notifier.signOut()` (also `features/auth/`) — both
  already exist, so there is no repository call of this feature's own to
  justify either layer (root `CLAUDE.md`'s "a feature only has the layers it
  needs"). Account-settings-style additions (edit name, addresses, etc.) are
  SCR-10's call, not a reason to scaffold empty layers here now.
- 🔴 **The identity line never shows a phone number.** `AuthUser` is
  `uid` + `email?` only; a phone-authenticated user has `email == null`, and
  the screen shows `AppStrings.profilePhoneLoginLabel` ("เข้าสู่ระบบด้วยเบอร์
  โทร") instead. This is a deliberate PII decision (`ADR-0037` Amendment 4
  A4-D2 #5, applying `ADR-0020` D9), not a gap — do **not** add a phone field
  to `AuthUser` just to fill this in. `home_screen_test.dart` and
  `profile_screen_test.dart` both assert no phone-shaped string ever renders
  here.
- **Sign-out requires confirmation.** `_confirmSignOut` shows an `AlertDialog`
  before calling `signOut()` — this replaced the old
  `HomeBottomNavBar`'s Profile tab, which called
  `ref.read(authViewModelProvider.notifier).signOut()` directly on tap, with
  no confirmation at all. Don't reintroduce a direct-signOut tap target
  anywhere in this feature.
- **Dialog dismissal goes through `context.pop<bool>(...)`, not
  `Navigator.of(context)`.** `lib/` bans `Navigator` outright
  (`test/core/router/no_imperative_navigation_test.dart`, empty allowlist).
  `showDialog`'s default `useRootNavigator: true` puts the dialog on the same
  Navigator `go_router` manages, so `context.pop()` closes the dialog rather
  than the screen underneath — the same mechanism
  `condition_grade_guide_sheet.dart`'s close button uses, verified there for
  a bottom sheet rather than a dialog but resting on the identical Navigator
  plumbing (`core/CLAUDE.md`'s `router/` entry has the full explanation).
- Reachable at `AppRoutes.profilePath` (`/profile`), behind `AuthGate` — this
  screen reads `AuthUser`, which only exists once signed in. System back does
  not leave the app: `PopScope(canPop: false)` routes it to `/home`
  (`ADR-0037` A4-D2 #6), same as `orders/`.
- Bottom nav is `core/widgets/app_bottom_nav_bar.dart`'s `AppBottomNavBar` —
  shared with `home/` and `orders/`, not owned by this feature.
