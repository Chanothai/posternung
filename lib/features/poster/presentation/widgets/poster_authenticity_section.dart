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
///
/// Restyled per ADR-0012 §D1 (figma 7:1008): the section owns its own top
/// divider now (rather than the caller adding a bare `SizedBox` gap before
/// it), the icon sits inside a 48px ring, and the verified/unverified label
/// is promoted to its own 16px-bold heading with the note as 14px body text
/// beside it. Still exactly the same two inputs as before —
/// `is_authenticated` and `authenticity_note`, nothing about "Certificate of
/// Authenticity" (ADR-0012 §D8).
class PosterAuthenticitySection extends StatelessWidget {
  const PosterAuthenticitySection({
    super.key,
    required this.isAuthenticated,
    required this.authenticityNote,
  });

  final bool isAuthenticated;
  final String? authenticityNote;

  static const _ringSize = 48.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(
          color: AppColors.borderMuted,
          height: AppSpacing.xl,
          thickness: 1,
        ),
        Text(
          AppStrings.posterDetailAuthenticitySectionTitle,
          style: AppTextStyles.homeSectionHeading,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: _ringSize,
              height: _ringSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isAuthenticated
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
              ),
              child: Icon(
                isAuthenticated
                    ? Icons.gpp_good_outlined
                    : Icons.gpp_maybe_outlined,
                size: 20,
                color: isAuthenticated
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAuthenticated
                        ? AppStrings.posterDetailAuthenticVerifiedLabel
                        : AppStrings.posterDetailAuthenticUnverifiedLabel,
                    style: AppTextStyles.homeSectionHeading.copyWith(
                      fontSize: 16,
                    ),
                  ),
                  if (authenticityNote != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(authenticityNote!, style: AppTextStyles.cardSubtitle),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
