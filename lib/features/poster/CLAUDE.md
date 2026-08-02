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
                  # imports that core type directly.
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
                  # PosterDetailsAccordion (AC-2/§D3 — provenance, size,
                  # description; any null field's row is omitted, not
                  # shown as "-"; the whole accordion is omitted if every
                  # field is null), PosterNotFoundView (AC-6, 404 — no
                  # retry, the id genuinely doesn't exist),
                  # PosterErrorView (generic network/server failure — has
                  # retry).
```

## Things worth knowing before touching this feature

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
  year anywhere (the `posters` table has no year column — SCR-03's G8;
  `era_decade` is a decade, not a release year). `PosterSummary` mirrors
  that exactly. Adding a field because the detail screen shows it means
  inventing data.
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
