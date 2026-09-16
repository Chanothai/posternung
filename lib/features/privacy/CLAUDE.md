# lib/features/privacy/

SCR-07 AC-5 — the `/privacy` notice (`ADR-0020` D11, Amendment 5).

```
presentation/
  screens/  # PrivacyScreen — the only file in this feature
```

## Things worth knowing before touching this feature

- **No `data/`/`domain/` folder.** This screen renders static strings only
  — no repository call to justify either layer (root `CLAUDE.md`'s "a
  feature only has the layers it needs"), same reasoning as
  `features/orders/`/`features/profile/`.
- **Public route** — the only screen in this app reachable without signing
  in besides onboarding/login themselves. `ADR-0020` D9/PDPA require the
  notice to be readable at the moment data is collected, which cannot be
  gated behind a session.
- 🔴 **This is a draft, not the legal-reviewed final text** —
  `AppStrings.privacyDraftBadge` ("ฉบับร่าง — รอเจ้าของ") is rendered on the
  page itself, not left as a source comment (`ADR-0020` Amendment 5 A5-D2).
  `SCR-07` AC-5 stays open in `docs/screens.yaml` until `BACKLOG.md` BL-150
  ④ (the owner's legal-reviewed copy) lands — closing AC-5 before that
  happens would be a false status, not a shortcut.
- 🔴 **Every string in `AppStrings`' Privacy block is `ADR-0020` D11 with
  exactly two bullet lines removed** (the TikTok and Omise recipients — both
  false since `ADR-0029` moved payment and Beta has no shipping-carrier
  integration). Nothing else was reworded. **Do not paraphrase, "clean up,"
  or reorganize any of this text without the owner** — root `CLAUDE.md`'s
  "เมื่อไหร่หยุด" section is explicit that user-facing text with a legal
  dimension is a stop-and-ask case, not a judgment call this repo's
  conventions can resolve on their own.
- Forbidden vocabulary carried over from D11 and still enforced by
  `test/features/privacy/presentation/screens/privacy_screen_test.dart`:
  "รับรอง" / "การันตี" (over-promising a guarantee this business cannot back),
  plus "TikTok"/"Omise" specifically (both now false claims about who
  receives data — see above).
