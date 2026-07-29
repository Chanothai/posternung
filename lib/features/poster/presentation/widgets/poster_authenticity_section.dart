import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// ADR-0005 §D2 — shows only fields that have real data behind them:
/// `is_authenticated` and `authenticity_note`. **Does not** show any
/// "Certificate of Authenticity" wording — US-16 is deferred (no schema
/// support for "has a COA" or a COA photo yet, see `docs/screens.yaml`'s
/// `deferred_stories` for SCR-05). `provenance` is shown in the details
/// accordion instead (`PosterDetailsAccordion`), not duplicated here.
class PosterAuthenticitySection extends StatelessWidget {
  const PosterAuthenticitySection({
    super.key,
    required this.isAuthenticated,
    required this.authenticityNote,
  });

  final bool isAuthenticated;
  final String? authenticityNote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.posterDetailAuthenticitySectionTitle,
          style: AppTextStyles.homeSectionHeading,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(
              isAuthenticated ? Icons.verified_outlined : Icons.info_outline,
              size: 18,
              color: isAuthenticated
                  ? AppColors.accent
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                isAuthenticated
                    ? AppStrings.posterDetailAuthenticVerifiedLabel
                    : AppStrings.posterDetailAuthenticUnverifiedLabel,
                style: AppTextStyles.homePosterSubtitle,
              ),
            ),
          ],
        ),
        if (authenticityNote != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(authenticityNote!, style: AppTextStyles.bodyDescription),
        ],
      ],
    );
  }
}
