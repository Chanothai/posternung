import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/error/order_exception.dart';
import '../../../../core/router/app_navigation.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_circle_button.dart';
import '../../../poster/domain/entities/poster_detail.dart';
import '../checkout_error_display.dart';
import '../providers/checkout_view_model.dart';
import '../providers/reservation_countdown_provider.dart';
import '../state/checkout_state.dart';
import '../widgets/checkout_address_form.dart';
import '../widgets/checkout_countdown_header.dart';
import '../widgets/checkout_order_created_view.dart';
import '../widgets/checkout_order_summary.dart';
import '../widgets/checkout_reservation_lost_view.dart';

/// `/checkout` (SCR-07 B1/B2/B4/B5). One page — address + shipping-note +
/// order summary + privacy link + submit — no progress indicator
/// (`ADR-0035` D4 Amendment 1). The countdown is a pinned
/// [SliverPersistentHeader] so it stays on screen the whole time (AC-8).
///
/// [posterSnapshot] is display-only, read once at the moment the route
/// builds this screen (same convention as `OtpVerificationScreen.
/// phoneNumber`) — the reservation itself is read live from
/// `checkoutFlowProvider`/`reservationCountdownProvider` by the ViewModel
/// and the countdown provider respectively.
///
/// Leaving (SCR-07 B9, B8-3): the header carries the same glass back button
/// SCR-05 has, and the whole screen sits in a `PopScope(canPop: true)` —
/// back is **always** allowed, with no confirm dialog. The reservation lives
/// server-side for its 60 minutes regardless of this screen, and
/// `ADR-0037` A5 makes tapping "ซื้อเลย" again return the same reservation,
/// so there is nothing to warn the buyer about. `CheckoutFlowObserver`
/// clears the flow on the resulting `didPop`; nothing here duplicates that.
///
/// Styling comes from `AppTheme` (`core/theme/app_theme.dart`) and
/// `AppSectionCard`; this file names no colour, radius or font of its own
/// beyond the sticky bar's tokens — `test/features/checkout/
/// checkout_no_hardcoded_style_test.dart` scans for regressions.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({required this.posterSnapshot, super.key});

  final PosterDetail posterSnapshot;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientName = TextEditingController();
  final _recipientPhone = TextEditingController();
  final _addressLine = TextEditingController();
  final _subDistrict = TextEditingController();
  final _district = TextEditingController();
  final _province = TextEditingController();
  final _postalCode = TextEditingController();

  @override
  void dispose() {
    _recipientName.dispose();
    _recipientPhone.dispose();
    _addressLine.dispose();
    _subDistrict.dispose();
    _district.dispose();
    _province.dispose();
    _postalCode.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final address = CheckoutAddressForm.read(
      recipientName: _recipientName,
      recipientPhone: _recipientPhone,
      addressLine: _addressLine,
      subDistrict: _subDistrict,
      district: _district,
      province: _province,
      postalCode: _postalCode,
    );
    ref.read(checkoutViewModelProvider.notifier).submit(address);
  }

  @override
  Widget build(BuildContext context) {
    final CheckoutState state = ref.watch(checkoutViewModelProvider);
    final bool showsForm = switch (state) {
      CheckoutReady() || CheckoutSubmitting() || CheckoutFailed() => true,
      CheckoutOrderCreated() || CheckoutReservationLost() => false,
    };

    return PopScope(
      canPop: true,
      child: Scaffold(
        // Same header treatment as SCR-05: the bar floats over the body
        // (transparent via `AppTheme.appBarTheme`), so the body paints
        // underneath it and offsets itself through `SafeArea` below.
        extendBodyBehindAppBar: true,
        // The sticky CTA bar blurs what scrolls under it, which needs the
        // body to actually extend beneath it — the form's scroll view adds
        // the bar's height as trailing padding so nothing is hidden.
        extendBody: showsForm,
        appBar: AppBar(
          leadingWidth: AppSpacing.lg + GlassCircleButton.hitArea,
          leading: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.lg),
            child: GlassCircleButton(
              icon: Icons.arrow_back,
              tooltip: AppStrings.checkoutBackButtonTooltip,
              onPressed: () => context.popOrGoHome(),
            ),
          ),
        ),
        body: SafeArea(bottom: !showsForm, child: _body(state)),
        bottomNavigationBar: showsForm
            ? _StickyCtaBar(
                isSubmitting: state is CheckoutSubmitting,
                onSubmit: _onSubmit,
              )
            : null,
      ),
    );
  }

  Widget _body(CheckoutState state) {
    return switch (state) {
      CheckoutOrderCreated(:final order) => CheckoutOrderCreatedView(
        order: order,
        onBackHome: () => context.go(AppRoutes.homePath),
      ),
      CheckoutReservationLost(:final exception) => CheckoutReservationLostView(
        message: checkoutOrderErrorDisplayMessage(
          exception,
          fallback: AppStrings.checkoutErrorReservationExpired,
        ),
        onBackToPoster: () => context.popOrGoHome(),
      ),
      CheckoutReady() ||
      CheckoutSubmitting() ||
      CheckoutFailed() => _formBody(state),
    };
  }

  Widget _formBody(CheckoutState state) {
    final Duration remaining = ref.watch(reservationCountdownProvider);
    final bool isSubmitting = state is CheckoutSubmitting;
    final OrderException? failure = state is CheckoutFailed
        ? state.exception
        : null;
    final Set<String> invalidFields = failure?.code == 'VALIDATION_ERROR'
        ? failure!.validationFields.toSet()
        : const {};

    // A `Builder` so the trailing padding below reads the `MediaQuery` the
    // *Scaffold* provides to its body (`extendBody` puts the sticky bar's
    // height there) — this State's own `context` sits above the Scaffold
    // and would read the window's inset instead.
    return Builder(
      builder: (BuildContext context) => CustomScrollView(
        slivers: [
          CheckoutCountdownHeader(remaining: remaining),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckoutOrderSummary(poster: widget.posterSnapshot),
                  const SizedBox(height: AppSpacing.xl),
                  CheckoutAddressForm(
                    formKey: _formKey,
                    recipientNameController: _recipientName,
                    recipientPhoneController: _recipientPhone,
                    addressLineController: _addressLine,
                    subDistrictController: _subDistrict,
                    districtController: _district,
                    provinceController: _province,
                    postalCodeController: _postalCode,
                    invalidFields: invalidFields,
                    enabled: !isSubmitting,
                    onPrivacyTap: () => context.push(AppRoutes.privacyPath),
                  ),
                  if (failure != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _FailureBanner(
                      message: checkoutOrderErrorDisplayMessage(
                        failure,
                        fallback: AppStrings.authErrorServer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // `extendBody` hands the sticky bar's height to the body as bottom
          // padding; reserving it here is what lets the last field scroll out
          // from under the bar instead of being covered by it.
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
}

/// The blurred bar pinned to the bottom of the form (Figma 7:1201 —
/// `stickyBarFill` at 85% over a 6px backdrop blur, `stickyBarBorder` top
/// rule). Holds the one primary CTA; the button itself carries no style of
/// its own — `AppTheme.elevatedButtonTheme` is what makes it the accent
/// pill with the `ctaLabel` face.
///
/// Padding is Figma's 17 / 24 / 32 mapped to `AppSpacing.lg` / `xl` / `xxl`
/// (the 17 → 16 delta is recorded in the B9 gate report). The bottom value
/// is a `SafeArea.minimum`, so on a device with a home indicator the larger
/// of the two wins rather than both stacking.
class _StickyCtaBar extends StatelessWidget {
  const _StickyCtaBar({required this.isSubmitting, required this.onSubmit});

  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.stickyBarFill,
            border: Border(top: BorderSide(color: AppColors.stickyBarBorder)),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onSubmit,
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Text(AppStrings.checkoutSubmitButtonLabel),
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.message});

  final String message;

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
        message,
        style: AppTextStyles.cardSubtitle.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
