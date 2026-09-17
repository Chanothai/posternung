import 'package:flutter/material.dart';

import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../domain/entities/order.dart';

/// `POST /orders` succeeded — rendered **in place** on `/checkout`
/// (`ADR-0037` A4-D1/A4-D2), never routed anywhere else.
///
/// 🔴 Closed-world by design (`test-quality` §4 — see
/// `checkout_screen_test.dart`): exactly **one** tappable control
/// ("กลับหน้าแรก") *in this view* — the screen's header back button (B9-1)
/// is the only other one on screen and the test names both — and the word
/// "สำเร็จ" must never appear anywhere on this view (Consequence 5 — an
/// order that cannot be paid for yet must not be told to the buyer as
/// already bought).
class CheckoutOrderCreatedView extends StatelessWidget {
  const CheckoutOrderCreatedView({
    required this.order,
    required this.onBackHome,
    super.key,
  });

  final Order order;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: AppSectionCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.checkoutOrderCreatedTitle,
                style: AppTextStyles.sectionTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${AppStrings.checkoutOrderCreatedOrderNoPrefix}'
                '${order.orderNo}',
                style: AppTextStyles.cardSubtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    AppStrings.checkoutOrderCreatedBadge,
                    style: AppTextStyles.statusActionLabel.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppStrings.checkoutOrderCreatedBodyLine1,
                style: AppTextStyles.cardSubtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.checkoutOrderCreatedBodyLine2,
                style: AppTextStyles.cardSubtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              // No style of its own — `AppTheme.elevatedButtonTheme` is the
              // accent pill with the `ctaLabel` face (B8-UI: an unstyled
              // label here used to fall back to Roboto).
              ElevatedButton(
                onPressed: onBackHome,
                child: const Text(AppStrings.checkoutOrderCreatedHomeCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
