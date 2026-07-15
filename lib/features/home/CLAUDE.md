# lib/features/home/

Presentation-only for now — no `data/`/`domain/` layer, because there's no poster/catalog repository yet. Add those layers the moment a real backend exists; don't scaffold them empty in the meantime.

```
presentation/
  models/     # HomeCollection / HomePoster — plain presentation-layer data classes
              # (not domain entities) backing the mock content in home_mock_data.dart.
              # This is placeholder catalog data, not translatable UI copy — it does
              # NOT go through AppStrings.
  screens/    # HomeScreen — post-login poster marketplace listing (top bar +
              # featured collections + ending soon + all posters + bottom nav)
  widgets/    # HomeTopBar, HomeTopBarHeaderDelegate, HomeBottomNavBar,
              # HomePosterCard, HomeCollectionCard, and one *_section.dart per
              # content section
```

- Every affordance not yet backed by real data/navigation (search, wishlist, cart, "View all", "Load More Titles") shows the shared coming-soon snackbar via `showComingSoonSnackBar()` in `home_coming_soon.dart` — reuse that helper for any new not-yet-implemented tap target instead of writing another ad hoc `SnackBar`.
- The bottom nav's Profile tab calls `ref.read(authViewModelProvider.notifier).signOut()` directly (from `features/auth/`) — this is the one place `home/` reaches into `auth/`'s presentation providers.
- All 10 SVG icons under `assets/images/` used by this feature were fetched from Figma and needed two rounds of fixes: some had NaN cubic-bezier control points (`Cnan nan` — flutter_svg's path parser throws a `StateError` on this), and all had `fill="var(--fill-0, #hex)"` (a CSS custom property flutter_svg's XML parser can't resolve, leaving the icon invisible). If you fetch a new Figma icon for this feature, check for both patterns before wiring it in.
- All user-facing copy in this feature comes from `AppStrings` (`core/strings/app_strings.dart`, `// --- Home ---` section) — except the mock catalog content noted above and the cart badge count, which are data values, not copy.
- The top bar continuously collapses/reappears as you scroll (hides on scroll down, floats back in on scroll up at any depth, fully disappears). It's built the framework-idiomatic way: `HomeScreen` is a `CustomScrollView` whose first sliver is a `SliverPersistentHeader(floating: true)` driven by `HomeTopBarHeaderDelegate` (`minExtent: 0`), wrapping the **unmodified** `HomeTopBar`. The sections are `SliverToBoxAdapter`s. Do **not** reintroduce an `Align(heightFactor:)`/`Transform` collapse hand-rolled off a `ScrollController` listener — that relayouts the bar's whole subtree every scroll frame and janks; the sliver protocol does the collapse in the Viewport's single layout pass instead. `_HomeScreenState` keeps only a one-time post-frame `GlobalKey` measurement of the bar's real height (fed into `maxExtent`, fallback `130.0`) — no per-frame state. The delegate's `build()` clips the bar via `ClipRect` + `OverflowBox` (child stays unbounded so it never overflows during the first-frame fallback) and wraps it in a `RepaintBoundary`.
