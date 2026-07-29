# lib/features/poster/

Catalog feature — full three-layer Clean Architecture slice (real data
dependency: `GET /posters/{poster_id}`). Named `poster`, not
`product_detail`, because SCR-03/04/05/11 (all catalog screens) are meant
to share this feature's DTO/entities rather than each getting their own —
see ADR-0005's rationale for the naming.

```
domain/
  entities/       # PosterDetail, PosterImage, PosterStatus (+
                  # posterStatusFromApi). PosterConditionGrade itself is
                  # NOT here — it lives in core/catalog/ so the shared
                  # core/widgets/condition_grade_indicator.dart can be typed
                  # against it without core importing features/ (see
                  # lib/core/CLAUDE.md's catalog/ entry). PosterDetail just
                  # imports that core type directly.
  repositories/   # PosterRepository — abstract, one method:
                  # getPosterDetail(posterId)
  usecases/       # GetPosterDetail — single call()
data/
  models/         # PosterDetailModel, PosterImageModel — @freezed +
                  # json_serializable, decode `status`/`condition_grade` as
                  # raw String? and map them in toEntity() via
                  # posterStatusFromApi/posterConditionGradeFromApi rather
                  # than @JsonEnum, so an unrecognized value degrades
                  # gracefully (condition_grade → null) or throws a
                  # CatalogException with a code (status — there's no
                  # legitimate null/unknown status) instead of a bare
                  # fromJson TypeError.
  datasources/    # PosterRemoteDataSource — Dio → GET
                  # /api/v1/posters/{poster_id}, via the shared dioProvider
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
                  # repository → usecase) + PosterDetailViewModel, an
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
  reflects that (`PosterConditionGrade?`), and `ConditionGradeIndicator`
  (core/widgets/) renders a plain "ไม่ระบุสภาพ" status badge for `null`
  rather than nothing at all — every call site pairs this widget with the
  price in the same row, and hiding it entirely would leave the price
  floating with no condition next to it, violating BR-05. Don't add a
  fallback/*fake* grade here though; ADR-0003 explicitly forbids that.
- **No real entry point into this screen yet.** `features/home/`'s
  `HomePosterCard` still shows `showComingSoonSnackBar()` on tap — it does
  **not** `Navigator.push` here. An earlier attempt wired the card straight
  to `PosterDetailScreen(posterId: poster.id)` using `HomePoster`'s
  placeholder mock ids (e.g. `'mock-blade-runner'`), which 404s against the
  real backend on every tap since Home has no real catalog repository of
  its own yet — that wiring was reverted (see `docs/screens.yaml` SCR-05's
  `known_gaps`) until Home is wired to `GET /posters` with real ids in a
  separate round. This whole feature slice is otherwise complete and has
  its own tests exercising `PosterDetailScreen` directly
  (`ProviderScope(overrides: [...])`, no navigation needed) — it just has
  no caller yet, which is expected, not dead code.
