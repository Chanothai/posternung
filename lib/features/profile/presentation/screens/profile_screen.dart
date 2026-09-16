import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/app_dimens.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/tab_back_to_home_scope.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/session_provider.dart';

/// SCR-07 B7 — the profile tab. Shows the signed-in identity and the one
/// action this round has: sign out, behind a confirm dialog.
///
/// This screen only ever renders behind `AuthGate` (see `app_router.dart`),
/// so `sessionProvider` is guaranteed non-null data by the time it builds —
/// but it still reads through `AsyncValue.value` rather than assuming that,
/// since a `ConsumerWidget` re-runs `build` on every rebuild of whatever it
/// watches, including a brief window where a session refresh is in flight.
///
/// No `data/`/`domain/` folder: everything here reads `sessionProvider`
/// (already published by `features/auth/`) and calls
/// `authViewModelProvider.notifier.signOut()` — there is no repository call
/// of its own to justify either layer (root `CLAUDE.md`'s "a feature only
/// has the layers it needs").
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  /// Shows the sign-out confirm dialog and returns once it's closed. `true`
  /// only when the user tapped the confirm action.
  ///
  /// Closes via `context.pop<bool>(...)`, never `Navigator.of(context)` —
  /// `lib/` bans `Navigator` outright (`no_imperative_navigation_test.dart`).
  /// `showDialog`'s default `useRootNavigator: true` puts the dialog on the
  /// same Navigator `go_router` itself manages, so `context.pop()` closes
  /// the dialog rather than the screen underneath it — verified the same
  /// way `condition_grade_guide_sheet.dart`'s dismissal button was.
  Future<bool> _confirmSignOut(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          AppStrings.profileSignOutConfirmTitle,
          style: AppTextStyles.authCardHeading,
        ),
        content: Text(
          AppStrings.profileSignOutConfirmBody,
          style: AppTextStyles.bodyDescription,
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop<bool>(false),
            child: const Text(AppStrings.profileSignOutConfirmCancel),
          ),
          TextButton(
            onPressed: () => dialogContext.pop<bool>(true),
            child: Text(
              AppStrings.profileSignOutConfirmConfirm,
              style: const TextStyle(color: AppColors.accentRed),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _onSignOutTap(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await _confirmSignOut(context);
    if (!confirmed) return;
    await ref.read(authViewModelProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthUser? user = ref.watch(sessionProvider).value;
    // Phone-only sign-in leaves `email` null (A4-D2 #5) — `AuthUser` has no
    // phone field to fall back to, and none is added just to show one here
    // (ADR-0020 D9: no new PII surface).
    final String identityLine =
        user?.email ?? AppStrings.profilePhoneLoginLabel;

    return TabBackToHomeScope(
      child: Scaffold(
        backgroundColor: AppColors.surfaceDark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AppGradientBackground(),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.glassCardFill,
                        border: Border.all(color: AppColors.glassCardBorder),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_circle_outlined,
                            size: AppDimens.iconMd,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              identityLine,
                              style: AppTextStyles.authCardHeading,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    OutlinedButton(
                      onPressed: () => _onSignOutTap(context, ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accentRed,
                        side: const BorderSide(color: AppColors.accentRed),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                      ),
                      child: const Text(AppStrings.profileSignOutButton),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: const AppBottomNavBar(),
      ),
    );
  }
}
