# lib/features/poster/

Catalog feature — full three-layer Clean Architecture slice over both
catalog endpoints: `GET /posters/{poster_id}` (detail) and `GET /posters`
(list). Named `poster`, not `product_detail`, because SCR-03/04/05/11 (all
catalog screens) share this feature's DTO/entities rather than each getting
their own — the root `CLAUDE.md`'s feature-first rule is what puts shared
code in one feature slice instead of duplicating it per screen (ADR-0005
decided the *scope* of SCR-05, not this repo's folder layout). The list line
is already shared: SCR-03's screen state lives in `features/home/` but reads
`GetPosters` from here.

```
domain/
  entities/       # PosterDetail, PosterSummary, PaginatedPosters,
                  # PosterImage, PosterStatus (+
                  # posterStatusFromApi). PosterConditionGrade itself is
                  # NOT here — it lives in core/catalog/ so the shared
                  # core/widgets/condition_grade_indicator.dart can be typed
                  # against it without core importing features/ (see
                  # lib/core/CLAUDE.md's catalog/ entry). PosterDetail just
                  # imports that core type directly — same for the 4 newer
                  # core/catalog/ enums (PosterType, ReleaseRegion,
                  # SizeFormat, RestorationStatus) that back PosterDetail's
                  # 9 ADR-0011 fields (poster_type, release_region,
                  # release_date_text, release_date, copyright_year,
                  # size_format, year, restoration_status,
                  # restoration_note) — release_date is parsed but never
                  # rendered (§D3); the other 8 all reach the screen.
  repositories/   # PosterRepository — abstract:
                  # getPosterDetail(posterId), listPosters(limit, offset)
  usecases/       # GetPosterDetail, GetPosters — single call() each.
                  # GetPosters clamps limit to the contract's 1..100 so an
                  # off-by-one becomes a smaller page, not a 422.
data/
  models/         # PosterDetailModel, PosterSummaryModel,
                  # PaginatedPostersModel, PosterImageModel — @freezed +
                  # json_serializable, decode `status`/`condition_grade` as
                  # raw String? and map them in toEntity() via
                  # posterStatusFromApi/posterConditionGradeFromApi rather
                  # than @JsonEnum, so an unrecognized value degrades
                  # gracefully instead of a bare fromJson TypeError. What
                  # an unrecognized *status* does differs by endpoint on
                  # purpose — see "detail throws, list degrades" below.
  datasources/    # PosterRemoteDataSource — Dio → GET
                  # /api/v1/posters/{poster_id} and GET /api/v1/posters
                  # (limit/offset only), via the shared dioProvider
                  # (core/network/api_client.dart) — no separate Dio
                  # instance. Public endpoint; no skipAuth needed (the
                  # AuthInterceptor attaching a Bearer token when one
                  # happens to exist is harmless — the backend route
                  # doesn't require it).
  repositories/   # PosterRepositoryImpl — maps DioException/any other
                  # failure into CatalogException (core/error/) before it
                  # crosses into domain/.
presentation/
  providers/      # poster_providers.dart — DI chain (datasource →
                  # repository → usecases: getPosterDetailProvider,
                  # getPostersProvider) + PosterDetailViewModel, an
                  # AsyncNotifier<PosterDetail> **family** keyed by
                  # posterId (AsyncNotifierProvider.family — see riverpod
                  # 3.3.2's overrideWith2 for how tests override a specific
                  # family instance's notifier). refresh() re-fetches
                  # without first flipping state to AsyncLoading, so the
                  # screen keeps showing whatever it has (data or error)
                  # while the request is in flight — used by both
                  # pull-to-refresh and the app-resume listener below.
                  # **Explicitly passes `retry: (retryCount, error) => null`**
                  # — Riverpod 3's `ProviderContainer.defaultRetry` silently
                  # auto-retries a failed `build()` up to 10x with
                  # exponential backoff for any error that isn't a
                  # `ProviderException`/`Error` (a plain `CatalogException`
                  # qualifies), which would otherwise turn a 404 into ~10
                  # repeated requests and a long stuck spinner before
                  # `PosterErrorView`/`PosterNotFoundView` ever appears —
                  # this screen already has its own explicit, user-triggered
                  # retry button, so the automatic one must stay off. Forget
                  # this on a future family provider with a manual retry UI
                  # and its error-path tests will hang/timeout waiting on
                  # `.future` — that's what surfaced this originally.
  screens/        # PosterDetailScreen (SCR-05) — a
                  # WidgetsBindingObserver that calls
                  # notifier.refresh() on AppLifecycleState.resumed
                  # (ADR-0005 §D5's AC-5: "poster sold while you were
                  # looking at it" is handled by re-fetch on
                  # foreground-resume + pull-to-refresh, not polling —
                  # there's no reservation/payment tied to this read-only
                  # screen yet to give a more precise signal).
  widgets/        # PosterDetailImageGallery (AC-1 — PageView +
                  # InteractiveViewer pinch-zoom, framework-native, no new
                  # dependency), PosterAvailabilityStatus (AC-4 as a status
                  # message, not a quantity selector — ADR-0005 §D1 forbids
                  # any control implying a purchase flow this round),
                  # PosterSoldBanner (AC-5's "way forward" — stays on the
                  # same screen, doesn't replace the whole listing),
                  # PosterAuthenticitySection (ADR-0005 §D2 — only
                  # is_authenticated + authenticity_note; provenance lives
                  # in the accordion instead, not duplicated),
                  # PosterDetailsAccordion (AC-2/§D3, flattened by
                  # ADR-0011 §D1′ — poster_type, size, release_date_text,
                  # copyright_year, provenance, restoration_note,
                  # description, plus release_region *only* when it's
                  # ReleaseRegion.unknown; any null/blank field's row is
                  # omitted, never shown as "-", and the whole accordion is
                  # omitted if every field is null/blank),
                  # PosterRestorationBadge (ADR-0011 §D2′, added SCR-05
                  # "แสดงฟิลด์ใหม่" — fact-only label next to price/grade for
                  # RESTORED/LINEN_BACKED only; NONE/UNKNOWN/null all render
                  # nothing — UNKNOWN was shown in round 1 of this feature,
                  # then reverted at GATE 3 as an explicit, narrow exception
                  # to §D7 scoped to this one badge, not a §D7 reversal.
                  # Owns the single `showsFor()` rule PosterDetailScreen
                  # also reads — never duplicate that condition at the call
                  # site),
                  # PosterNotFoundView (AC-6, 404 — no retry, the id
                  # genuinely doesn't exist), PosterErrorView (generic
                  # network/server failure — has retry).
```

## Things worth knowing before touching this feature

- **Zoom in the gallery disables *two* scrollables, and both are load-bearing.**
  `InteractiveViewer` drives a single `ScaleGestureRecognizer`, which only
  claims the gesture arena once the focal point travels `kPanSlop` (36lp) — a
  `Scrollable`'s drag recognizer claims at `kTouchSlop` (18lp) and therefore
  always wins first, at every zoom level. So while zoomed,
  `PosterDetailImageGallery` puts its `PageView` on
  `NeverScrollableScrollPhysics` **and** reports up through `onZoomChanged` so
  `_PosterDetailBody` does the same to the outer `ListView` (vertical pan, same
  root cause). Drop either half and a one-finger drag on a zoomed image goes
  back to flipping the page / scrolling the screen away. Pinch was never
  affected — a second pointer makes the mono-drag recognizer reject itself.
  `minScale: 1` is deliberate too: the framework default of 0.8 lets "zoomed
  all the way out" settle *below* identity, which would leave the swipe locked.
  **No widget test can catch a regression here** — the tests pin the state
  machine (flag flips, physics follows), not the arena outcome against a real
  touch stream. That needs a device. Found on-device *after* `code-critic` had
  already passed SCR-05.
- **The zoom button belongs in the app bar, not on the image.** It was on the
  image first and device verification killed that: `BoxFit.contain` letterboxes
  any poster whose ratio isn't 2:3, and a control pinned to the frame's corner
  then floats in the empty band — measured at ~100pt clear of the artwork,
  reading as a control for the whole screen. Anchoring it to the *painted*
  image would mean resolving each image's intrinsic size first, which is why
  it moved into `actions:` instead: always present, never letterboxed, and
  sharing the bar with the fading title rather than swapping with it.
  `PosterGalleryZoomController` is what lets it live outside the gallery — the
  gallery attaches on init and **detaches on dispose**, so the screen can't be
  left holding a zoom flag whose image is gone (that flag drives the list's
  physics; stranded `true` means a permanently unscrollable screen).
- **Zoom has four entry points on purpose, and they share one code path.**
  Pinch, double tap, the app bar button and the hint text all end at
  `_toggleZoom`, so
  they cannot disagree about what "zoomed" means — and zooming out always
  targets identity, which is what re-arms the swipe. Device verification found
  buyers never discovering pinch at all; that matters more here than on a
  normal gallery, because zooming *is* how condition gets inspected before
  buying (BR-05, ADR-0003), hence the hint saying **why** to zoom rather
  than how. The hint sits *above* the page dots and below the image on
  purpose: under the dots it read as a caption describing them. The double tap is safe to add precisely because it needs no
  travel: it resolves on tap count, never entering the slop race the fix above
  turns on. Anything new that *does* drag (a dismiss-on-swipe-down, say) has
  to re-check that race.
  Also: assigning `_transformationController.value` directly bypasses
  `InteractiveViewer`'s boundary clamp — it only enforces bounds inside its
  own gesture handlers — so `_zoomedInMatrix` clamps the translation itself.
  Skip that and a double tap near an edge parks blank space in frame.
- **The app bar's title fades in; it does not collapse a header.** The bar
  keeps its height and its back button at every offset, and
  `_CollapsingAppBarTitle` only crosses the poster title in as the image
  scrolls away. Hosting the gallery in a `FlexibleSpaceBar` instead would put
  it back inside a scrollable that moves under the finger mid-zoom, undoing
  the gesture work above — that's why this shape, not that one.
  The fade is keyed to the image's height **capped at `maxScrollExtent`**.
  Uncapped it is unreachable in the ordinary case: a 2:3 image on a phone is
  ~537pt tall against ~500pt of total scroll, so the title would simply never
  appear. Also note `maxScrollExtent`/`pixels` *throw* before the list has
  laid out — the bar builds first, so both need a `hasContentDimensions` /
  `hasPixels` guard rather than a default.
- **`PosterErrorView` and `PosterNotFoundView` render through
  `AppStatusView`** (core/widgets/) — the same block SCR-03's error/empty
  states use. They keep their own identities (different copy, different
  tone, retry vs. go-back) but no longer own any layout or styling; adjust
  the shared widget rather than restyling one of them in place.
- **This round is read-only (ADR-0005 §D1).** No Add to Cart, no quantity
  selector — `POST /cart/reserve/{poster_id}` is still `x-status: DRAFT` in
  the contract. Don't add a purchase CTA here without checking whether that
  DRAFT status has actually been lifted first.
- **US-16 (COA) is deferred**, not implemented partially — see
  `docs/screens.yaml`'s `deferred_stories` entry for SCR-05 and
  ADR-0005 §D2. Never derive "has a COA" from `is_authenticated`; they mean
  different things and the schema has no COA-photo field at all yet.
- **`sold` and `404` are different failure shapes, handled by different
  widgets** (`PosterSoldBanner` vs `PosterNotFoundView`) — the backend does
  not filter `GET /posters/{poster_id}` by status (ADR-0005 §D5), so a sold
  poster is a normal `200` response, not an error at all. Only
  `POSTER_NOT_FOUND` is a `CatalogException`; `error` in
  `PosterDetailScreen`'s `AsyncValue.when` is specifically that — a real
  fetch failure, not "unavailable."
- **`condition_grade` is nullable with no backend guard** — `PosterDetail`
  and `PosterSummary` both reflect that (`PosterConditionGrade?`), and
  `ConditionGradeIndicator` (core/widgets/) renders a plain "ไม่ระบุสภาพ"
  status badge for `null` rather than nothing at all — every call site pairs
  this widget with the price, and hiding it entirely would leave the price
  with no condition next to it, violating BR-05. Don't add a fallback/*fake*
  grade here though; ADR-0003 explicitly forbids that. The widget has a
  `compact: true` variant for SCR-03's grid cells (tighter padding, no info
  icon, **same** `"Very Good (5/8)"` text) — if a new dense call site
  doesn't fit, add a variant there rather than a second badge widget, so
  ADR-0003 stays enforced in exactly one place.
- **The list line is a strictly smaller shape than the detail line — don't
  copy fields across.** `PosterListItem` has exactly
  `id/title/price/status/condition_grade/era_decade/studio/primary_image_url`.
  There is **no** `size`, **no** `is_unique`, **no** `images`, and no film
  `year` — `posters.year` exists as a column (ADR-0009, added by INF-06)
  and reaches the app through `PosterDetail.year`/`PosterDetailModel`, but
  **the column has 0 rows of actual data on SIT today** (`year` column
  existing ≠ `year` data existing — don't build anything on this feature
  that assumes real values are there yet) and
  `PosterListItem`/`PosterSummary` were never extended to carry it anyway
  (ADR-0009 §D11 — detail-only, no `PosterListItem` change this round).
  `era_decade` stays a decade, not a release year, on both shapes.
  `PosterSummary` mirrors `PosterListItem` exactly. Adding a field because
  the detail screen shows it means inventing data on the list line — the
  9 fields ADR-0011 ("แสดงฟิลด์ใหม่") added (`poster_type` ·
  `release_region` · `release_date_text` · `release_date` ·
  `copyright_year` · `size_format` · `year` · `restoration_status` ·
  `restoration_note`) all landed on `PosterDetail` only, same rule.
- **`price` is a `String` on the wire, on both endpoints.** Pydantic v2
  serializes `Decimal` to a JSON string (`"450.00"`) and the contract says
  `type: string, format: decimal`. Typing it `num`/`double` compiles and
  then fails at runtime on the first real response. It stays a `String`
  end-to-end; `formatThbPrice` (`core/utils/`) formats it for display.
- **Detail throws on an unrecognized `status`; list degrades to `null`.**
  Deliberate asymmetry. On detail, a bad status affects the one poster the
  user asked for, so failing loudly with a `CatalogException` is right. On
  a list it would take the whole page down for every other poster — the
  same blast radius as the backend's own G6, where one internal image key
  500s all of `GET /posters`. `PosterSummary.status` is therefore
  `PosterStatus?`, and `null` must be treated exactly like `reserved`:
  shown as unavailable, never as buyable.
- **No `sort` param exists, and the client must not compensate.** The
  backend orders `GET /posters` by `created_at DESC`, which is what
  satisfies BR-05 ("the default sort must not be cheapest-first"). Sorting
  by price in `toEntity()`, the repository, or a widget re-introduces the
  violation the backend already avoids. Pinned by tests in both
  `poster_summary_model_test.dart` and home's screen test.
- **`in_stock_only` defaults to `false` server-side**, so a page
  legitimately contains `reserved`/`sold` rows. That is AC-4's input, not a
  bug and not something to filter out client-side.
- **`primary_image_url` is nullable *and* absent-able** — it isn't in the
  schema's `required` list, and the backend returns `null` when the primary
  image sits under an internal-only storage key. Every call site needs a
  deliberate placeholder rather than a broken frame.
- **This screen now has a real caller.** `features/home/`'s
  `HomeAllPostersSection` `Navigator.push`es `PosterDetailScreen(posterId:
  poster.id)` with the **real backend UUID** from `GET /posters`. An earlier
  attempt used `HomePoster`'s placeholder mock ids (e.g.
  `'mock-blade-runner'`) and 404'd on every tap; that was reverted and is
  only safe now because Home reads real ids. Never wire this screen to a
  synthesized id. Unavailable posters are still pushed here on purpose —
  the detail endpoint doesn't filter by status (ADR-0005 §D5) and
  `PosterSoldBanner` is the fuller explanation.
