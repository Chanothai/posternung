import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/app_dimens.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/error/order_exception.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../checkout/presentation/checkout_error_display.dart';
import '../../../checkout/presentation/providers/reserve_listing_view_model.dart';
import '../../../checkout/presentation/state/reserve_listing_state.dart';
import '../../domain/entities/poster_detail.dart';
import '../../domain/entities/poster_status.dart';
import '../providers/poster_providers.dart';

/// The "ซื้อเลย" button (SCR-07 B3) — `PosterDetailScreen`'s only entry
/// point into the reserve/checkout flow.
///
/// Cross-feature import by design, not a layering violation: this file
/// imports `checkout/`'s presentation providers and display mapper
/// directly, the same way `onboarding/`'s `OnboardingEntryGate` imports
/// `auth/`'s `sessionProvider` — see
/// `ReserveListingViewModel`'s doc comment for the full reasoning. `data/`
/// never crosses either direction.
///
/// 🔴 Renders on `available` **and** `reserved`, and is never disabled based
/// on `status` (`ADR-0037` D4, SCR-07 AC-15) — the backend is the sole judge
/// of whether a reservation succeeds, because it is also the only thing
/// that can lazy-expire a stale reservation (`ADR-0033` D4). Renders nothing
/// at all on `sold` — `PosterSoldBanner` already gives that state its own
/// way forward, and AC-15's "don't block lazy-expire" reasoning doesn't
/// apply to a poster that isn't merely reserved.
class PosterBuyNowButton extends ConsumerWidget {
  const PosterBuyNowButton({super.key, required this.poster});

  final PosterDetail poster;

  /// Reserve failure codes that mean "this listing's own availability
  /// changed" — the only ones SCR-07 AC-9 asks this screen to refresh for.
  /// `BUYER_IS_SELLER`/`RESERVATION_LIMIT_EXCEEDED`/`RESERVE_RATE_LIMITED`
  /// and transport failures are about the buyer or the network, not this
  /// poster's stock, so refreshing on those would just be a wasted request.
  /// Table source: `docs/status/gates/SCR-07-sliceB-gate1.md` §4 "reserve".
  static const Set<String> _refreshingCodes = {
    'POSTER_NOT_FOUND',
    'POSTER_NOT_AVAILABLE',
    'POSTER_ALREADY_RESERVED',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (poster.status == PosterStatus.sold) return const SizedBox.shrink();

    final ReserveListingState state = ref.watch(
      reserveListingViewModelProvider(poster.id),
    );
    final bool isSubmitting = state is ReserveListingSubmitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isSubmitting ? null : () => _onPressed(context, ref),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.white,
              minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              elevation: 0,
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Text(AppStrings.posterDetailBuyNowButtonLabel),
          ),
        ),
        if (state is ReserveListingFailed) ...[
          const SizedBox(height: AppSpacing.sm),
          _ReserveFailureNotice(exception: state.exception),
        ],
      ],
    );
  }

  Future<void> _onPressed(BuildContext context, WidgetRef ref) async {
    final reservation = await ref
        .read(reserveListingViewModelProvider(poster.id).notifier)
        .reserve(poster);

    // F4 — the buyer may have left this screen (back, or the poster went
    // out of scope some other way) while `reserve()` was still in flight.
    // `context`/`ref` are unsafe to touch once that happens: reading a
    // provider through a disposed `WidgetRef` throws `StateError` ("Using
    // 'ref' when a widget is about to or has been unmounted is unsafe" —
    // `flutter_riverpod-3.3.2/lib/src/core/consumer.dart`'s
    // `_assertNotDisposed`), and this guard has to run before *every* use of
    // either one below, not just the navigation call.
    if (!context.mounted) return;

    if (reservation != null) {
      context.push(AppRoutes.checkoutPath);
      return;
    }

    // AC-9 — only refresh when the failure means the listing's own
    // availability changed; see `_refreshingCodes`' doc comment.
    final ReserveListingState after = ref.read(
      reserveListingViewModelProvider(poster.id),
    );
    if (after is ReserveListingFailed &&
        _refreshingCodes.contains(after.exception.code)) {
      ref.read(posterDetailViewModelProvider(poster.id).notifier).refresh();
    }
  }
}

/// The inline notice under the button (GATE 1 §3 item 3 — never a
/// `SnackBar`: a message like "ถึง 15:30 น." has to stay readable, not
/// disappear on its own timer). Same container shape as `checkout_screen.
/// dart`'s `_FailureBanner` — kept as a separate, smaller widget here rather
/// than shared, because that one also needs the `CheckoutFailed`/
/// `CheckoutReservationLost` distinction this button never has.
class _ReserveFailureNotice extends StatelessWidget {
  const _ReserveFailureNotice({required this.exception});

  final OrderException exception;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentRedSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.accentRed),
      ),
      child: Text(
        reserveErrorDisplayMessage(
          exception,
          fallback: AppStrings.authErrorServer,
        ),
        style: const TextStyle(color: AppColors.textPrimary),
      ),
    );
  }
}
