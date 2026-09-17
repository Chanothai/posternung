import 'package:flutter/material.dart';

import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A section block on the dark ground (Figma 7:1201 — added SCR-07 B9):
/// `sectionFill` wash, 1px `sectionBorder`, 12px corners, with an optional
/// H3 [title] set in `AppTextStyles.sectionHeading` over a `sectionBorder`
/// rule.
///
/// A `core/` widget, not a checkout one: any screen that groups content into
/// a titled block (order summary, address form, a profile section, a filter
/// group) should build on this rather than hand-rolling a `Container` +
/// `BoxDecoration` — the glass-card look the first version of `/checkout`
/// used (`glassCardFill`, 8% white) is almost invisible on `surfaceDark`,
/// which is exactly the drift a shared widget stops.
///
/// Figma's 21px inner padding has no `AppSpacing` step; `AppSpacing.xl`
/// (24) is the nearest and is used rather than a literal.
class AppSectionCard extends StatelessWidget {
  const AppSectionCard({required this.child, this.title, super.key});

  /// Optional H3. When `null` the card is just the bordered wash around
  /// [child].
  final String? title;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final String? title = this.title;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.sectionFill,
        border: Border.all(color: AppColors.sectionBorder),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title, style: AppTextStyles.sectionHeading),
            const SizedBox(height: AppSpacing.md),
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.sectionBorder,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          child,
        ],
      ),
    );
  }
}
