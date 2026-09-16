import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/widgets/app_status_view.dart';

/// The reservation is gone — expired locally (AC-11) or the backend said so
/// (AC-4/AC-9). One control: back to the poster (SCR-05 already refreshes
/// on resume, so the buyer sees the poster's current, real availability
/// rather than this screen guessing at it).
class CheckoutReservationLostView extends StatelessWidget {
  const CheckoutReservationLostView({
    required this.message,
    required this.onBackToPoster,
    super.key,
  });

  final String message;
  final VoidCallback onBackToPoster;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: AppStatusView(
          icon: Icons.timer_off_outlined,
          title: AppStrings.checkoutReservationLostTitle,
          body: message,
          tone: AppStatusTone.error,
          actionLabel: AppStrings.checkoutReservationLostBackCta,
          onAction: onBackToPoster,
        ),
      ),
    );
  }
}
