import 'package:flutter/material.dart';

import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/router/app_navigation.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';

/// `/privacy` (SCR-07 AC-5, `ADR-0020` D11 + Amendment 5). Public — reachable
/// without signing in, because the notice has to be readable at the moment
/// data is collected, and PDPA doesn't require a session to read it.
///
/// 🔴 **Draft, not final** — `AppStrings.privacyDraftBadge` ("ฉบับร่าง —
/// รอเจ้าของ") is part of this page's rendered output on purpose (A5-D2), not
/// a source comment. The body text is `ADR-0020` D11 with exactly two
/// bullet lines removed (TikTok/Omise, both false since `ADR-0029`) — see
/// `AppStrings`' Privacy block for the line-by-line provenance. Do not
/// paraphrase any of it without the owner (root `CLAUDE.md` "เมื่อไหร่หยุด").
///
/// No `data/`/`domain/` folder: this screen renders static strings only,
/// same reasoning as `OrdersPlaceholderScreen`/`ProfileScreen` (root
/// `CLAUDE.md` "a feature only has the layers it needs").
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppGradientBackground(),
          SafeArea(
            child: Column(
              children: [
                _AppBar(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: [
                      _DraftBadge(),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        AppStrings.privacyPageTitle,
                        style: AppTextStyles.authCardHeading,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _Body(AppStrings.privacyControllerBody),
                      const SizedBox(height: AppSpacing.xl),
                      _Section(
                        heading: AppStrings.privacyWhatWeCollectHeading,
                        body: const [
                          AppStrings.privacyWhatWeCollectBody1,
                          AppStrings.privacyWhatWeCollectBody2,
                        ],
                      ),
                      _Section(
                        heading: AppStrings.privacyWhyHeading,
                        body: const [
                          AppStrings.privacyWhyBody1,
                          AppStrings.privacyWhyBody2,
                        ],
                      ),
                      _Section(
                        heading: AppStrings.privacyRecipientsHeading,
                        body: const [
                          AppStrings.privacyRecipientFirebase,
                          AppStrings.privacyRecipientGoogleDrive,
                          AppStrings.privacyNoSellingData,
                        ],
                      ),
                      _Section(
                        heading: AppStrings.privacyRetentionHeading,
                        body: const [
                          AppStrings.privacyRetentionShipping,
                          AppStrings.privacyRetentionFinancial,
                          AppStrings.privacyRetentionAccount,
                        ],
                      ),
                      _Section(
                        heading: AppStrings.privacyContactHeading,
                        body: const [
                          AppStrings.privacyContactBody1,
                          AppStrings.privacyContactBody2,
                          AppStrings.privacyContactBody3,
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            // F9 — `context.pop()` throws `GoError('There is nothing to
            // pop')` when `/privacy` is the only entry on the stack (a deep
            // link, or a restored process) — `popOrGoHome()` is the same
            // fix `PosterDetailScreen` already uses for the same reason.
            onPressed: () => context.popOrGoHome(),
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _DraftBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.accentRedSoft,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.accentRed),
        ),
        child: Text(
          AppStrings.privacyDraftBadge,
          style: AppTextStyles.statusActionLabel.copyWith(
            color: AppColors.accentRed,
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.heading, required this.body});

  final String heading;
  final List<String> body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: AppTextStyles.authCardHeading),
          const SizedBox(height: AppSpacing.sm),
          for (final line in body) _Body(line),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text, style: AppTextStyles.cardSubtitle),
    );
  }
}
