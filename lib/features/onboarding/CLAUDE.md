# lib/features/onboarding/

Presentation-only — no `data/` or `domain/` layer, since onboarding has no data dependency (per the "a feature only has the layers it needs" rule in root `CLAUDE.md`).

```
presentation/
  providers/    # OnboardingController — shared page-index state, 3 pages
  screens/      # OnboardingPageViewScreen — single PageView-based screen hosting
                # all 3 onboarding pages, swipeable, with a shared header/footer
  widgets/      # shared chrome (header, footer, progress indicator, primary button)
                # + one *_page_content.dart per page (first/authenticate/limit_stock)
```

- `OnboardingPageViewScreen` owns a `PageController`; the progress indicator and footer both key off it directly (via `AnimatedBuilder`) rather than piping per-frame scroll position through Riverpod state, which would fan out rebuilds.
- The "Next" button's default label (`AppStrings.onboardingNextButton`) is shared across `OnboardingFooter`, `OnboardingPrimaryButton`, and the explicit pass on the last page (which swaps to `onboardingGetStartedButton`) — don't reintroduce a separate hardcoded "ถัดไป" literal anywhere in this feature; reuse the constant.
- Onboarding's final screen hands off via `AuthGate` (from `features/auth/`) — see that feature's `CLAUDE.md` for what happens next.
