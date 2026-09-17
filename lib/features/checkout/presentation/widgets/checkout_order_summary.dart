import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../poster/domain/entities/poster_detail.dart';

/// The order summary block (SCR-07 AC-3/AC-1, BUSINESS_RULES.md BR-B3) —
/// poster snapshot (title, price) from `CheckoutFlowState.posterSnapshot`
/// plus a shipping-fee row that is **always ฿0** in Closed Beta, with the
/// owner's exact wording for why. No live `GET /posters/{id}` here — this is
/// a snapshot, not a fresh read.
///
/// 🔴 F3 — the product price row (`formatThbPrice(poster.price)`, same
/// helper every other poster-listing screen uses) was missing entirely
/// before this fix: the widget showed the title and a shipping-fee row, but
/// never the price BR-B3 requires the checkout page to show.
class CheckoutOrderSummary extends StatelessWidget {
  const CheckoutOrderSummary({required this.poster, super.key});

  final PosterDetail poster;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: AppStrings.checkoutSummaryTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            poster.title,
            style: AppTextStyles.bodyDescription.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.checkoutSummaryProductPriceLabel,
                style: AppTextStyles.cardSubtitle,
              ),
              Text(
                formatThbPrice(poster.price),
                style: AppTextStyles.cardSubtitle,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.checkoutSummaryShippingFeeLabel,
                style: AppTextStyles.cardSubtitle,
              ),
              Text(
                AppStrings.checkoutSummaryShippingFeeFree,
                style: AppTextStyles.cardSubtitle,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.checkoutSummaryShippingNote,
            style: AppTextStyles.cardSubtitle,
          ),
        ],
      ),
    );
  }
}
