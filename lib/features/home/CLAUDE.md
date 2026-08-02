# lib/features/home/

SCR-03 Home / Discover. **No longer presentation-only** — it now renders the
real catalog from `GET /posters`. It still has no `data/`/`domain/` folder of
its own, and must not grow one: the DTO, entity, repository and usecase for
`GET /posters` live in `features/poster/` because SCR-03/04/05/11 all read the
same endpoint, and the root `CLAUDE.md`'s feature-first rule keeps shared code
in one slice rather than copied per screen. What lives here is the *screen's*
state — the ViewModel — and its widgets.

```
presentation/
  providers/  # home_posters_provider.dart — HomePostersViewModel,
              # AsyncNotifier<HomePostersState> over features/poster/'s
              # GetPosters usecase. Auto-retry is switched OFF (see below).
  state/      # home_posters_state.dart — the accumulated grid plus
              # isLoadingMore/loadMoreError, i.e. the two paging facts an
              # AsyncValue cannot hold without discarding the grid.
  screens/    # HomeScreen — top bar + catalog grid + bottom nav, wrapped in
              # a RefreshIndicator. No lifecycle observer: this screen calls
              # the backend only when the user asks (see below).
  widgets/    # HomeTopBar, HomeTopBarHeaderDelegate, HomeBottomNavBar,
              # HomeAllPostersSection (owns all four required states),
              # HomePosterCard, HomeLoadMoreFooter, HomePostersEmptyView,
              # HomePostersErrorView, home_coming_soon.dart
```

## Things worth knowing before touching this feature

- **Featured Collections and Ending Soon were deleted, not disabled.** There
  is no curation table, no tag/genre column, and no expiry timestamp in the
  schema, so both sections could only ever have shown invented data. Their
  widgets, the shared `HomeLoopingCarousel`, and `home_mock_data.dart` were
  removed in the same change. Don't reintroduce a "Featured" strip without a
  schema and an endpoint behind it.
- **The old mock set expectations the API cannot meet.** `HomePoster`'s
  subtitle was `'1982 • US Original'` — a *film year* and a *size*. `GET
  /posters` returns neither (there is no year column at all; `size` exists
  only on the detail response). The card's subtitle is now `era_decade` +
  `studio`, and is omitted entirely when both are null. Treat any remaining
  design reference to year/size on a card as spec drift, not a gap to fill.
- **`homePostersProvider` disables Riverpod's automatic retry**
  (`retry: (_, __) => null`). Riverpod 3 otherwise retries a failed `build()`
  up to 10x with exponential backoff for any error that isn't a
  `ProviderException`/`Error` — a `CatalogException` qualifies — so a dead
  backend would leave Home spinning for tens of seconds and
  `HomePostersErrorView`'s retry button would never render. Same reasoning,
  same footgun, as `posterDetailViewModelProvider`.
- **Four required states, and only one of them is screen-wide.**
  `HomeAllPostersSection` switches loading/error/empty; `sold_out` is
  *per row*, rendered by `HomePosterCard` from `PosterSummary.status`. Empty
  is `total == 0` — not `items.isEmpty`, which would also be true for an
  offset past the end of a non-empty catalog.
- **The grid is never re-sorted here.** The backend orders by `created_at
  DESC` and there is no `sort` query param; sorting by price client-side
  would violate BR-05's "the default sort must not be cheapest-first". Both
  `PaginatedPostersModel` and `home_screen_test.dart` have a test pinning the
  order.
- **Unavailable cards stay tappable.** `status != available` gets a scrim and
  a badge so it doesn't look buyable, but the tap still opens
  `PosterDetailScreen`, where `PosterSoldBanner` explains what happened —
  `GET /posters/{id}` doesn't filter by status (ADR-0005 §D5).
- **Navigation is a bare `Navigator.push` with the real backend UUID.** No
  `go_router`: there's no route table yet and adding one is SCR-06's call. The
  id must come from the API — an earlier attempt used placeholder ids and
  404'd on every tap (`lib/features/poster/CLAUDE.md`).
- **Home calls the backend only when the user asks it to** — pull-to-refresh,
  the load-more pager, retry. There is **no** `WidgetsBindingObserver`
  re-fetching on `AppLifecycleState.resumed` (removed deliberately: every
  foreground switch re-read the whole loaded span, up to N requests once the
  user had paged down). Don't add polling or a lifecycle trigger back without
  saying explicitly what changed. A poster that sells while the app is
  backgrounded therefore keeps its old badge on the grid until the user pulls
  to refresh — `stock-integrity`'s mobile requirement is still met at the
  point it matters, because `PosterDetailScreen` **does** re-fetch on resume
  and shows `PosterSoldBanner`, so nothing can be bought off a stale card.
- **`HomePosterCard`'s layout constraints are load-bearing.** The image is
  `Expanded` so the card absorbs the grid's fixed `mainAxisExtent` there
  rather than overflowing when the text block grows; price and condition are
  on separate lines because a 2-up cell (~140–165 px) cannot fit
  "฿1,250.00" beside "Very Good (5/8)". The condition badge is
  `ConditionGradeIndicator(compact: true)` from `core/widgets/` — **never** a
  bare `Text(grade)`, which is what this screen did before and what ADR-0003
  forbids ("Fine" outranks "Very Good", so a lone label misleads).
- **The error and empty states are `AppStatusView` (core/widgets/), not their
  own layouts.** `HomePostersErrorView`/`HomePostersEmptyView` are now thin
  wrappers that pick the icon, tone, copy and CTA; the card, typography and
  pill button come from the shared widget SCR-05's error/not-found views also
  use. Change the look there, not here, or the two screens drift apart again.
- Affordances still not backed by anything real — search, wishlist heart,
  cart — go through `showComingSoonSnackBar()` in `home_coming_soon.dart`.
  Reuse that helper rather than another ad hoc `SnackBar`.
- **The grid pages, and paging is what shapes the state class.**
  `HomeLoadMoreFooter` appends the next 20 rows (`GET /posters?offset=`) and
  renders only while `items.length < total`, so a fully-loaded catalog shows
  neither a count line nor a button that would fetch an empty page. The two
  facts a paging screen needs — *loading more* and *this page failed* — both
  happen while data is on screen, so they live on `HomePostersState`
  (`presentation/state/`), **not** on the `AsyncValue`: flipping the
  provider to `AsyncLoading`/`AsyncError` for an optional extra page would
  throw away the grid the user is reading. Keep it that way. The
  `AsyncValue` union still covers the *first* page only.
- **`refresh()` re-reads the whole loaded span, not page one.** Once the user
  has paged to 60 rows, refreshing only the first 20 would leave 40 stale
  rows — and staleness is the entire reason this screen refreshes
  (`stock-integrity`). `_fetchSpan` asks for `items.length` rows, split into
  consecutive chunks of at most `GetPosters.maxLimit` (100) because the
  contract 422s above that. Never collapse it back to a single-page fetch.
- **Rows are deduped by id on every append and every multi-chunk refresh.**
  Offset pagination over `created_at DESC` re-sends the boundary row
  whenever a poster is listed between two requests; without
  `HomePostersState._mergeById` the grid would show it twice.
- **All three entry points (`refresh`/`retry`/`loadMore`) share one
  `_inFlight` slot** — a load-more tap landing mid-refresh joins it rather
  than appending to a list being rewritten underneath it. The slot is
  cleared via `whenComplete` on the tracked future, *not* a `finally` inside
  the async body: a data source that throws synchronously never reaches its
  first `await`, so a `finally` would run before `_inFlight` was assigned
  and wedge the slot permanently. This was a real bug, caught by the
  load-more retry test.
- The bottom nav's Profile tab calls
  `ref.read(authViewModelProvider.notifier).signOut()` directly (from
  `features/auth/`) — the one place `home/` reaches into `auth/`'s
  presentation providers. That call makes a network round-trip (`POST
  /auth/logout`); the tap site doesn't await it or show a loading state,
  which is harmless today (the revoke is best-effort and `AuthGate` swaps the
  screen away) but is where a spinner would go if one's ever wanted.
- All SVG icons under `assets/images/` used by this feature came from Figma
  and needed two rounds of fixes: some had NaN cubic-bezier control points
  (`Cnan nan` — flutter_svg's path parser throws a `StateError`), and all had
  `fill="var(--fill-0, #hex)"` (a CSS custom property flutter_svg can't
  resolve, leaving the icon invisible). Check both patterns before wiring in
  a new Figma icon.
- All user-facing copy comes from `AppStrings` (`core/strings/app_strings.dart`,
  `// --- Home ---` and `// --- Home / Discover catalog list ---`). Poster
  titles, prices and studios are backend data, not copy — they don't go
  through `AppStrings`.
- The top bar continuously collapses/reappears as you scroll (hides on scroll
  down, floats back in on scroll up at any depth). It's built the
  framework-idiomatic way: `HomeScreen` is a `CustomScrollView` whose first
  sliver is a `SliverPersistentHeader(floating: true)` driven by
  `HomeTopBarHeaderDelegate` (`minExtent: 0`) wrapping the **unmodified**
  `HomeTopBar`. Do **not** reintroduce an `Align(heightFactor:)`/`Transform`
  collapse hand-rolled off a `ScrollController` listener — that relayouts the
  bar's whole subtree every scroll frame and janks; the sliver protocol does
  the collapse in the Viewport's single layout pass. `_HomeScreenState` keeps
  only a one-time post-frame `GlobalKey` measurement of the bar's real height
  (fed into `maxExtent`, fallback `130.0`) — no per-frame state. A widget test
  for this behaviour must use the **default** 800x600 surface: on a tall test
  surface the whole grid fits and there is nothing to scroll, so the drag
  silently does nothing and the assertion fails for the wrong reason.
