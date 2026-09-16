# lib/features/orders/

SCR-07 B7 — the orders tab of `core/widgets/app_bottom_nav_bar.dart`.
**Placeholder only.** `OrdersPlaceholderScreen` renders a fixed "ยังไม่มี
คำสั่งซื้อ" (`AppStrings.ordersPlaceholderTitle`/`ordersPlaceholderBody`)
through `core/widgets/app_status_view.dart` — there is no `GET /orders` call
anywhere in this feature.

```
presentation/
  screens/  # OrdersPlaceholderScreen — the only file in this feature
```

## Things worth knowing before touching this feature

- **No `data/`/`domain/` folder, and don't add one for this screen.** Root
  `CLAUDE.md`'s rule is explicit: a feature only has the layers it needs, and
  this screen has no repository call to justify either. Add both — plus
  `presentation/providers/` and `presentation/state/` for the paginated list
  — the moment SCR-09 wires up the real endpoint. Don't scaffold them early
  "for consistency."
- **`SCR-09` is what replaces this file**, not what extends it. When that
  round lands, expect this screen to be rewritten wholesale rather than
  incrementally — there's no loading/error/empty state machinery here to
  reuse, just a static block.
- 🔴 **Never route `OrderCreatedView` here.** `ADR-0037` Amendment 4 A4-D1 is
  explicit: a screen saying "no orders yet" right after `POST /orders`
  succeeded would tell the user their order both exists and doesn't, in the
  same flow. `OrderCreatedView`'s only button goes to `/home`.
- Reachable at `AppRoutes.ordersPath` (`/orders`), behind `AuthGate` the same
  way `/home` is — a signed-out visitor has no orders either. Android/iOS
  system back does not leave the app from here: `PopScope(canPop: false)`
  routes it to `/home` instead (`ADR-0037` A4-D2 #6), the same as `profile/`.
- Bottom nav is `core/widgets/app_bottom_nav_bar.dart`'s `AppBottomNavBar` —
  shared with `home/` and `profile/`, not owned by this feature. Don't
  duplicate it here.
