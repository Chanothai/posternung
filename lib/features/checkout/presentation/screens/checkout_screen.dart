import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/app_dimens.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/error/order_exception.dart';
import '../../../../core/router/app_navigation.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
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

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(child: _body(state)),
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

    return CustomScrollView(
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
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : _onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size.fromHeight(
                        AppDimens.buttonHeight,
                      ),
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
                        : const Text(AppStrings.checkoutSubmitButtonLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
      child: Text(message, style: TextStyle(color: AppColors.textPrimary)),
    );
  }
}
