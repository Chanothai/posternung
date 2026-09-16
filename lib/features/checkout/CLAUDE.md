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
  screens/checkout_screen.dart
  widgets/
    checkout_countdown_header.dart   # pinned SliverPersistentHeader (AC-8)
    checkout_order_summary.dart
    checkout_address_form.dart
    checkout_order_created_view.dart
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
  reservation response was received), and `remaining = (expiresAt -
  createdAt) - stopwatch.elapsed` — the *server's* span, anchored once. This
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
  **B8 (device verification) is still out of this slice.**
