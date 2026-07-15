# lib/core/

Cross-feature, reusable code only. Nothing here imports from `lib/features/`.

- **`theme/`** — design tokens extracted from Figma: `AppColors` (colors), `AppTextStyles` (typography, `GoogleFonts.kanit` throughout for Thai-glyph coverage — see the note in `app_text_styles.dart`). Both are `abstract final class`es with `static const`/`static final` fields, grouped by feature with `// --- Feature ---` section comments as they're added.
- **`strings/`** — `AppStrings`, centralizing UI copy the same way `theme/` centralizes design tokens. Same convention: `abstract final class`, `static const String` fields, feature-prefixed names (`onboardingNextButton`, `authSubmitLogin`, `homeSectionAllPosters`, ...), section comments per feature. Genuinely shared wording (app name, the Thai "coming soon" message) gets one constant reused across features; text that only coincidentally matches gets its own separate constant — don't force-share across unrelated features just because two strings read the same.
- **`error/`** — shared domain exception types (`AuthException`, `AuthCancelledException`). Data-layer repository impls map SDK-specific exceptions (`FirebaseAuthException`, etc.) into these before they cross into `domain/`.
- **`config/`** — build-environment resolution: `Environment` enum, `environmentProvider`, `firebase_options_selector.dart` (picks between `lib/firebase_options_{sit,uat,production}.dart`). See root `CLAUDE.md`'s "Build environments" section and `docs/environments-setup.md` for the full picture.
- **`widgets/`** — generic reusable widgets used by 2+ features, e.g. `AppGradientBackground` (used by onboarding, login, and home).

`network/` and `utils/` are anticipated in the root architecture doc but don't exist yet — no feature has needed a shared API client or extension/formatter utilities so far. Don't scaffold them empty; add them the moment something actually needs them.
