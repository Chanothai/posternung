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
- **Page 2 has diverged from its Figma frame on purpose.** The frame (node 7:2) is titled "100% Authenticated Originals" and puts a "ยืนยันแล้ว" label under the centrepiece icon; both are gone. ADR-0014 D1 bans claiming the goods are certified authentic on every channel, so the page describes what the app lets a buyer *do* — zoom every image, read every attribute we hold — instead of what we vouch for. The icon itself stays (on its own it reads as a question mark in a dashed circle, not an external certification mark). **Don't "fix" this page back towards the design file**, and don't add copy here that describes our inspection process either — that layer is still blocked by ADR-0014 OD-2 pending legal review.
- `test/features/onboarding/onboarding_no_authenticity_claim_test.dart` enforces the above on every CI run, over `AppStrings` *and* the rendered widget tree. Adding a new `onboarding*` constant means adding it to that test's `_onboardingCopy` list — Dart has no reflection to enumerate the class.
