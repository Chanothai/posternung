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
  Future<Reservation?> reserve(PosterDetail posterSnapshot) async {
    state = const ReserveListingSubmitting();
    try {
      final Reservation reservation = await ref
          .read(reserveListingProvider)
          .call(_posterId);
      // F4/F6 — this notifier is `.autoDispose.family` (F6), and the caller
      // (`PosterBuyNowButton`) may have left the screen entirely while the
      // call above was in flight. If nothing watches `posterId` any more,
      // Riverpod has already disposed this element by the time we get here,
      // and `state = ...` on a disposed notifier throws `UnmountedRef
      // Exception` rather than being a harmless no-op — `ref.mounted` is
      // the framework's own documented way to check before touching state
      // after an async gap.
      if (!ref.mounted) return null;
      ref
          .read(checkoutFlowProvider.notifier)
          .start(
            CheckoutFlowState(
              reservation: reservation,
              posterSnapshot: posterSnapshot,
            ),
          );
      state = const ReserveListingIdle();
      return reservation;
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
