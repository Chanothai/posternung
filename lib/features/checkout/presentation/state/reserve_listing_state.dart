import '../../../../core/error/order_exception.dart';

/// State behind the "ซื้อเลย" button on `PosterDetailScreen` (SCR-07 B3).
///
/// Three states only, not the full MVI shape `CheckoutState` uses — this is
/// a single fire-and-forget action, not a multi-step flow, so
/// idle/submitting/failed is the whole state space (there is no "succeeded"
/// state: on success the flow hands off to `checkoutFlowProvider` and the
/// screen navigates away, per `ReserveListingViewModel.reserve()`'s doc
/// comment).
sealed class ReserveListingState {
  const ReserveListingState();
}

/// Nothing in flight — the button is enabled (unless the poster is `sold`,
/// which `PosterBuyNowButton` handles by not rendering itself at all).
class ReserveListingIdle extends ReserveListingState {
  const ReserveListingIdle();
}

/// `POST /listings/{poster_id}/reserve` is in flight. The button shows a
/// spinner and is disabled for the duration — the only time it is ever
/// disabled (SCR-07 AC-15: never disabled because of the poster's
/// `status`).
class ReserveListingSubmitting extends ReserveListingState {
  const ReserveListingSubmitting();
}

/// The reserve call failed. [exception] renders inline, under the button,
/// via `reserveErrorDisplayMessage()` — never a `SnackBar` (GATE 1 §3 item
/// 3: a message that says "จองไว้ถึง 15:30 น." has to stay readable, not
/// disappear on its own timer). The button returns to enabled immediately —
/// there is no code in this table that should ever leave it stuck disabled.
class ReserveListingFailed extends ReserveListingState {
  const ReserveListingFailed(this.exception);
  final OrderException exception;
}
