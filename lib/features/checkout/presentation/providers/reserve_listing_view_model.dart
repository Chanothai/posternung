import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/order_exception.dart';
import '../../../poster/domain/entities/poster_detail.dart';
import '../../domain/entities/reservation.dart';
import '../state/reserve_listing_state.dart';
import 'checkout_flow_provider.dart';
import 'checkout_providers.dart';

/// ViewModel behind the "ซื้อเลย" button on `PosterDetailScreen` (SCR-07 B3).
///
/// Lives in `checkout/` — not `poster/` — because every other piece of the
/// reserve flow already does: `ReserveListing` (the usecase),
/// `checkoutFlowProvider` (what `/checkout` reads), and
/// `reserveErrorDisplayMessage()` (the display mapper) all live here
/// already, prepared for exactly this call site. This class is the last
/// piece of that flow, not a new one, so it stays with the rest of it
/// rather than splitting the flow across two features.
///
/// `poster/`'s presentation layer imports [reserveListingViewModelProvider]
/// directly — the same shape `onboarding/`'s `OnboardingEntryGate` uses to
/// import `auth/`'s `sessionProvider`
/// (`lib/features/onboarding/presentation/onboarding_entry_gate.dart`).
/// Root `CLAUDE.md`'s feature-first rule is about *where a repository/
/// usecase lives* (next to the feature that owns the data), and *no layer
/// skips* (presentation never imports `data/`, domain never imports
/// Flutter/`data/`) — it says nothing against one feature's presentation
/// layer reading a provider another feature's presentation layer owns, and
/// `onboarding/` already does exactly that. `checkout/`'s `data/`/`domain/`
/// still never import anything from `poster/`, and `poster/`'s presentation
/// layer still never imports `checkout/`'s `data/` — both one-way rules
/// hold unchanged.
///
/// Family-keyed by `posterId`, same shape as `PosterDetailViewModel`
/// (`poster/presentation/providers/poster_providers.dart`) — a fresh idle
/// state whenever a different poster's screen mounts.
///
/// 🔴 The provider below is declared `.autoDispose.family` (F6) —
/// deliberately, not by Riverpod default: `NotifierProvider.family(...)`
/// alone is **not** auto-disposing in Riverpod 3.3.2 (same fact as
/// `checkout_view_model.dart`'s `checkoutViewModelProvider` doc comment,
/// F1). Without `.autoDispose` here, a `ReserveListingFailed` notice from
/// one failed tap outlived the screen and reappeared the next time the
/// buyer opened the same poster's detail page later in the session — this
/// class's per-visit idle state only actually happens because of the
/// `.autoDispose` on the declaration below, not because of anything the
/// framework does automatically.
class ReserveListingViewModel extends Notifier<ReserveListingState> {
  ReserveListingViewModel(this._posterId);

  final String _posterId;

  @override
  ReserveListingState build() => const ReserveListingIdle();

  /// Reserves this poster and, on success, hands the resulting [Reservation]
  /// off to `checkoutFlowProvider` together with [posterSnapshot] — the
  /// `PosterDetail` the screen already has loaded, so `/checkout` never
  /// needs a second `GET /posters/{id}` (`checkout/CLAUDE.md`).
  ///
  /// 🔴 Never gates the call on `poster.status` (SCR-07 AC-15) — see
  /// `ReserveListing`'s own doc comment for why the backend must be the sole
  /// judge of whether a reservation succeeds (it is also the only thing
  /// that can lazy-expire a stale reservation, `ADR-0033` D4). Call this
  /// unconditionally whenever the button is tapped.
  ///
  /// Returns the [Reservation] on success, so the caller (`PosterBuyNowButton`)
  /// knows to navigate to `/checkout`. Returns `null` on failure, leaving
  /// [state] as [ReserveListingFailed] for the button to render inline —
  /// there is no "succeeded" state on this notifier because the screen
  /// navigates away immediately, so [state] resets to [ReserveListingIdle]
  /// on success rather than staying `Submitting` for a screen that is about
  /// to be left.
  ///
  /// 🔴 On success the reservation is offered to `checkoutFlowProvider`
  /// **from here, before any `mounted` check** (`ADR-0037` Amendment 5
  /// A5-D2) — a response that lands after the buyer has left the screen is
  /// still kept, so the flow holds a reservation the server has already
  /// committed. The widget only decides whether to *navigate*.
  ///
  /// 🔴 "Offered", not "written": the flow is only taken if no *other*
  /// poster's flow is open (`CheckoutFlowNotifier.startIfOwnedBy`,
  /// code-critic 2026-09-17 F-High). When another poster already owns the
  /// flow — the buyer moved on to B and is on `/checkout` for B — this
  /// late response is dropped silently and `reserve` returns `null` with
  /// [state] back at [ReserveListingIdle] (no failure notice, no
  /// navigation, no refresh): nothing went wrong, and the server still
  /// holds this reservation for the buyer's next tap (A5-D1 replays it as
  /// 200).
  Future<Reservation?> reserve(PosterDetail posterSnapshot) async {
    state = const ReserveListingSubmitting();
    // 🔴 A5-D2 (`ADR-0037` Amendment 5) — grab the flow notifier **before**
    // the async gap. This notifier is `.autoDispose.family` (F6): if the
    // buyer leaves the screen while the call below is in flight, Riverpod
    // disposes this element before the response arrives, and `ref.read`
    // on a disposed `Ref` throws — so the 201 (or 200) that the backend
    // has already committed would be thrown away on the client, and the
    // buyer's next tap would get a 409 for a reservation that is their own
    // (N-2 in `SCR-07-sliceB-gate3.md`). `checkoutFlowProvider` is a plain
    // (non-autoDispose) provider, so the `CheckoutFlowNotifier` captured
    // here stays valid for the life of the container regardless of what
    // happens to *this* element — writing through it after we are gone is
    // safe, and is exactly what `test/.../poster_detail_screen_test.dart`'s
    // "unmount while in flight" test pins.
    final CheckoutFlowNotifier flow = ref.read(checkoutFlowProvider.notifier);
    try {
      final Reservation reservation = await ref
          .read(reserveListingProvider)
          .call(_posterId);
      // Offer the reservation to the flow first — mounted or not (A5-D2),
      // but through the owner-checked gate, never `start()` (F-High: an
      // unconditional write here is exactly the cross-poster overwrite the
      // critic's probe reproduced). Only *this* notifier's own `state` is
      // gated on `ref.mounted` below: `state = ...` on a disposed notifier
      // throws `UnmountedRefException` rather than being a harmless no-op,
      // and `ref.mounted` is the framework's own documented check for that.
      final bool accepted = flow.startIfOwnedBy(
        _posterId,
        CheckoutFlowState(
          reservation: reservation,
          posterSnapshot: posterSnapshot,
        ),
      );
      final Reservation? result = accepted ? reservation : null;
      if (!ref.mounted) return result;
      state = const ReserveListingIdle();
      return result;
    } on OrderException catch (e) {
      if (!ref.mounted) return null;
      state = ReserveListingFailed(e);
      return null;
    }
  }
}

final reserveListingViewModelProvider = NotifierProvider.autoDispose
    .family<ReserveListingViewModel, ReserveListingState, String>(
      ReserveListingViewModel.new,
    );
