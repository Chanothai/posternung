# lib/features/checkout/

SCR-07 B1/B2/B3/B4/B5/B6 — reservation → address form → order, plus the
`ReserveListingViewModel` that backs `poster/`'s "ซื้อเลย" button and the
no-local-persistence source scan (`test/core/no_local_persistence_test.dart`)
that guards this feature and `profile/`. First feature in this repo to
actually use the sealed-class (MVI) state shape root `CLAUDE.md`'s
Presentation section reserves for cart/checkout.

```
domain/
  entities/        # Reservation · ShippingAddress · Order · OrderStatus
  repositories/     # CheckoutRepository (abstract)
  usecases/         # ReserveListing · CreateOrder
data/
  models/           # ReservationModel · ShippingAddressModel · OrderModel (freezed)
  datasources/      # CheckoutRemoteDataSource (POST reserve/orders)
  repositories/     # CheckoutRepositoryImpl
presentation/
  providers/
    checkout_providers.dart          # DI: datasource → repository → usecases
    checkout_flow_provider.dart      # transient flow state (route doesn't hold it)
    reservation_countdown_provider.dart  # owns the Timer, split from CheckoutState
    checkout_view_model.dart         # CheckoutViewModel — the sealed CheckoutState
    reserve_listing_view_model.dart  # ReserveListingViewModel — idle/submitting/failed,
                                      # backs `poster/`'s "ซื้อเลย" button (SCR-07 B3)
  state/
    checkout_state.dart              # CheckoutReady/Submitting/Failed/ReservationLost/OrderCreated
    reserve_listing_state.dart       # ReserveListingIdle/Submitting/Failed
  checkout_error_display.dart        # ADR-0017 D4/D9 mapper — orders table (live) + reserve table (live, SCR-07 B3)
  checkout_flow_observer.dart        # clears checkoutFlowProvider on real didPop
  screens/checkout_screen.dart       # PopScope(canPop: true) + glass back button + sticky CTA bar (B9)
  widgets/
    checkout_countdown_header.dart   # pinned SliverPersistentHeader (AC-8)
    checkout_order_summary.dart      # AppSectionCard
    checkout_address_form.dart       # AppSectionCard; fields styled by AppTheme.inputDecorationTheme
    checkout_order_created_view.dart # AppSectionCard; CTA styled by AppTheme.elevatedButtonTheme
    checkout_reservation_lost_view.dart
```

## Things worth knowing before touching this feature

- **`/checkout` carries no arguments at all** (`ADR-0018` Amendment 2 A2-D2) —
  the reservation + a `PosterDetail` snapshot live in `checkoutFlowProvider`,
  read through `core/router/route_state_guard.dart`'s `requireRouteState`
  exactly like `/otp`/`/verify-email`. There is no
  `/checkout/:reservationId`: there is no `GET /reservations/{id}` to
  recover the flow from a path parameter alone if the app were killed
  mid-checkout, so the flow is treated as gone rather than half-restored.
- **The countdown is a *second*, separate provider from `CheckoutState`**
  (`reservation_countdown_provider.dart`), not a field on it. If `remaining`
  lived inside the same sealed state as the rest of the screen, every 1s
  tick would rebuild the whole address form the buyer is typing into.
- 🔴 **No `DateTime.now()` anywhere in the countdown.** `CheckoutFlowState`
  starts a `Stopwatch` the instant the flow begins (i.e. the moment the
  reservation response was received), and `remaining =
  reservation.countdownSpan - stopwatch.elapsed` — the *server's* span,
  anchored once. `countdownSpan` is `expiresAt - serverReceivedAt` (the
  response's `Date` header, parsed by `core/utils/http_date.dart` in the
  data source) so a **200** replay of an older reservation (A5-D1) counts
  down from what is actually left; it falls back to `expiresAt - createdAt`
  (exact for a 201) when the header is missing or malformed. This
  is the same reasoning `StartupTrace` uses elsewhere in this app for the
  same reason: a wall-clock read is only ever as good as the device's clock,
  and the backend is the actual authority on when the reservation expires
  (AC-4 makes this explicit — `POST /orders` re-checks server-side no
  matter what the client's countdown says).
- **AC-11's client-driven timeout reuses the exact same display pipeline as
  every backend error** — see `kCheckoutCountdownExpiredCode` in
  `checkout_error_display.dart`. `CheckoutViewModel` synthesizes an
  `OrderException` with that code rather than inventing a second way to get
  a message onto `CheckoutReservationLost`.
- **`Submitting` ignores the countdown reaching zero.** The backend is the
  sole judge of an in-flight `POST /orders` — same principle AC-15 already
  established for the reserve endpoint. `CheckoutOrderCreated` and
  `CheckoutReservationLost` are terminal and also ignore it, for the
  opposite reason: nothing should un-terminal them.
- **No subclass of `CheckoutState` holds a shipping address** (AC-2) — the
  form's values live only in `CheckoutScreen`'s own `TextEditingController`s.
  Leaving the screen after a failed submit and coming back starts from an
  empty form, on purpose; there is no local persistence of PII to restore
  from (AC-2 forbids it outright — `test/core/no_local_persistence_test.dart`
  (B6) is the source scan that guards both this and the absence of any
  local-storage import under this feature and `profile/`).
- **`checkout_error_display.dart` has two tables in one file**: the "orders"
  table is used by `CheckoutViewModel`/`CheckoutScreen`, the "reserve" table
  by `poster/`'s `PosterBuyNowButton` (SCR-07 B3) — both live now. This makes
  `checkout_error_display.dart` the third file in `lib/` calling
  `resolveErrorDisplay()` — the D9 closed-world scan in
  `test/core/error_message_safety_test.dart` counts files, not call sites,
  so having two functions in one file still counts as one.
- **`OrderException`'s typed fields, never `typedDetails`.** Every message
  that needs a parsed value (`reservedUntil`/`expiredAt`/`limit`/
  `retryAfter`) reads it off `OrderException` directly — never
  `BackendErrorEnvelope.typedDetails`, which a source scan in
  `test/core/error_message_safety_test.dart` bans under `presentation/`.
- **`OrderModel.status` never throws on an unrecognized value** — unlike
  `PosterDetailModel.status`. A buyer looking at the order they just placed
  should still see it (order number, "awaiting payment") even if a future
  backend status this build predates shows up; see `orderStatusFromApi`'s
  doc comment for why this endpoint's failure mode is "degrade to `null`",
  not "throw", unlike the single-poster read.
- **`ShippingAddressModel` has no `fromJson`/`.g.dart`** — this app never
  receives a shipping address back from the backend (`OrderResponse` omits
  it entirely, `ADR-0020` D5 ชั้น ก), so the DTO only ever travels
  `fromEntity()` → `toJson()`.
- **B3 is wired.** `ReserveListingViewModel` (`presentation/providers/
  reserve_listing_view_model.dart`) calls `ReserveListing` and, on success,
  starts `checkoutFlowProvider` — it is `poster/`'s `PosterBuyNowButton`
  that calls it, not anything in this feature's own screens. On failure it
  is `reserveErrorDisplayMessage` that renders the notice, same call site.
  🔴 `ADR-0037` A5-D2: the flow is started **from the notifier, before any
  `ref.mounted` check**, through a `CheckoutFlowNotifier` captured before
  the `await` — the VM is `.autoDispose.family` and may be gone when the
  200/201 lands (buyer left SCR-05), but the flow provider is not, so the
  server-committed reservation is kept. A5-D1: the data source treats
  200 (own still-active reservation) and 201 alike — Dio's `validateStatus`,
  pinned by a real-Dio test. A5-D4: 409 `BUYER_HAS_LIVE_ORDER` →
  `OrderException.orderNo` → `AppStrings.checkoutErrorBuyerHasLiveOrder`;
  `PosterBuyNowButton` hides itself on that **code** only (never on
  `status`, AC-15).
  **B8 (device verification) is still out of this slice.**
- **No style of its own (SCR-07 B9, B8-UI).** Colours, fonts, input and
  button looks come from `core/theme/app_theme.dart` + `AppColors`/
  `AppTextStyles`, sections from `core/widgets/app_section_card.dart`.
  `test/features/checkout/checkout_no_hardcoded_style_test.dart` bans
  `TextStyle(` / `Color(0x` / `fontFamily:` / Material `Colors.*` under this
  feature — add a token to `core/theme/` instead. The one per-field
  decoration `checkout_address_form.dart` still sets is the 422 highlight,
  and it points at the theme's own `errorBorder` rather than naming a colour.
- **Back is always allowed (B8-3).** `CheckoutScreen` wraps its `Scaffold`
  in `PopScope(canPop: true)` and shows the same `GlassCircleButton` back
  button SCR-05 has — no confirm dialog, because the reservation is
  server-side for its 60 minutes and `ADR-0037` A5 hands the same
  reservation back on a repeat "ซื้อเลย". `CheckoutFlowObserver.didPop`
  already clears the flow; the screen does not clear it a second time.
